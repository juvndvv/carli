<?php

namespace App\Modules\Health\Domain;

use App\Core\Models\UserModule;
use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Health\Models\BodyMeasurement;
use App\Modules\Health\Models\BodySite;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Tape measurements of the body: the sites, each session of measurements and how every site has changed.
 */
final readonly class BodyService
{
    /** Set once the default sites are created, so deleting them all doesn't bring them back. */
    private const string SEEDED = 'body_sites_seeded';

    /**
     * The user's sites in their order, creating the defaults the first time.
     *
     * @return Collection<int, BodySite>
     */
    public function sites(User $user, bool $withArchived = false): Collection
    {
        $this->seed($user);

        return BodySite::query()->ownedBy($user)
            ->when(! $withArchived, fn ($query) => $query->whereNull('archived_at'))
            ->orderBy('position')->orderBy('created_at')
            ->get();
    }

    /**
     * @param  array{name: string, zone: string, side?: string|null}  $data
     */
    public function create(User $user, array $data): BodySite
    {
        $this->seed($user);
        $site = new BodySite([
            'name' => $data['name'],
            'zone' => $data['zone'],
            'side' => in_array($data['zone'], BodySite::PAIRED, true) ? ($data['side'] ?? null) : null,
            'position' => (int) BodySite::query()->ownedBy($user)->max('position') + 1,
        ]);
        $site->user_id = $user->id;
        $site->save();

        return $site;
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(BodySite $site, array $data): BodySite
    {
        if (array_key_exists('name', $data)) {
            $site->name = (string) $data['name'];
        }
        if (array_key_exists('zone', $data)) {
            $site->zone = (string) $data['zone'];
        }
        if (array_key_exists('side', $data)) {
            $site->side = is_string($data['side']) ? $data['side'] : null;
        }
        if (! in_array($site->zone, BodySite::PAIRED, true)) {
            $site->side = null;
        }
        if (array_key_exists('archived', $data)) {
            $site->archived_at = $data['archived'] ? ($site->archived_at ?? CarbonImmutable::now()) : null;
        }
        $site->save();

        return $site;
    }

    /**
     * @param  list<string>  $ids
     */
    public function reorder(User $user, array $ids): void
    {
        DB::transaction(function () use ($user, $ids): void {
            foreach ($ids as $position => $id) {
                BodySite::query()->ownedBy($user)->whereKey($id)->update(['position' => $position]);
            }
        });
    }

    /**
     * One session with the tape: every value shares the same moment.
     *
     * @param  list<array{site_id: string, value_cm: float|int|string}>  $values
     * @return Collection<int, BodyMeasurement>
     */
    public function record(User $user, array $values, ?string $measuredAt = null): Collection
    {
        $moment = $measuredAt === null ? CarbonImmutable::now() : self::moment($measuredAt);

        return DB::transaction(function () use ($user, $values, $moment): Collection {
            $saved = new Collection;
            foreach ($values as $value) {
                $measurement = new BodyMeasurement([
                    'site_id' => $value['site_id'],
                    'measured_at' => $moment,
                    'value_cm' => number_format((float) $value['value_cm'], 1, '.', ''),
                ]);
                $measurement->user_id = $user->id;
                $measurement->save();
                $saved->push($measurement);
            }

            return $saved;
        });
    }

    /**
     * Every active site with its latest value and the value it had at the comparison point:
     * the first measurement ever ("first") or the last one on or before a day.
     *
     * @return array{sites: list<array<string, mixed>>, last_measured_at: string|null, measured_today: bool}
     */
    public function overview(User $user, string $compare = 'first'): array
    {
        $sites = $this->sites($user);
        $bySite = BodyMeasurement::query()->ownedBy($user)
            ->whereIn('site_id', $sites->modelKeys())
            ->orderBy('measured_at')
            ->get()
            ->groupBy('site_id');
        $until = $compare === 'first' ? null : HabitCalendar::date($compare)->addDay();
        $last = null;

        $rows = [];
        foreach ($sites as $site) {
            /** @var \Illuminate\Support\Collection<int, BodyMeasurement> $history */
            $history = $bySite->get($site->id) ?? collect();
            /** @var BodyMeasurement|null $latest */
            $latest = $history->last();
            /** @var BodyMeasurement|null $baseline */
            $baseline = $until === null
                ? $history->first()
                : $history->filter(fn (BodyMeasurement $m): bool => $m->measured_at->lessThan($until))->last();

            if ($latest !== null && ($last === null || $latest->measured_at->greaterThan($last))) {
                $last = $latest->measured_at;
            }

            if ($latest === null || $baseline === null || $baseline->id === $latest->id) {
                $baseline = null;
            }

            $rows[] = [
                'site' => $site,
                'latest' => $latest,
                'baseline' => $baseline,
                'change_cm' => $latest === null || $baseline === null ? null : round($latest->value() - $baseline->value(), 1),
                'count' => $history->count(),
            ];
        }

        return [
            'sites' => $rows,
            'last_measured_at' => $last?->toIso8601String(),
            'measured_today' => $last !== null && HabitCalendar::localDay($last)->equalTo(HabitCalendar::today()),
        ];
    }

    public function measuredOn(User $user, CarbonImmutable $day): bool
    {
        $start = HabitCalendar::date($day);

        return BodyMeasurement::query()->ownedBy($user)
            ->where('measured_at', '>=', $start)
            ->where('measured_at', '<', $start->addDay())
            ->exists();
    }

    private function seed(User $user): void
    {
        $record = UserModule::query()->firstOrNew(['user_id' => $user->id, 'module_id' => HealthSettings::MODULE]);
        $settings = $record->settings ?? [];

        if (($settings[self::SEEDED] ?? false) === true) {
            return;
        }

        DB::transaction(function () use ($user, $record, $settings): void {
            if (! BodySite::query()->ownedBy($user)->exists()) {
                foreach (BodySite::DEFAULTS as $position => [$name, $zone, $side]) {
                    $site = new BodySite(['name' => $name, 'zone' => $zone, 'side' => $side, 'position' => $position]);
                    $site->user_id = $user->id;
                    $site->save();
                }
            }
            $record->settings = [...$settings, self::SEEDED => true];
            $record->save();
        });
    }

    /**
     * The phone sends UTC; convert to the app's zone before Eloquent writes the wall time.
     */
    private static function moment(string $value): CarbonImmutable
    {
        return CarbonImmutable::parse($value)->setTimezone((string) config('app.timezone'));
    }
}
