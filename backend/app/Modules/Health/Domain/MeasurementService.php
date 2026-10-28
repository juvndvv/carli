<?php

namespace App\Modules\Health\Domain;

use App\Models\User;
use App\Modules\Habits\Domain\Support\HabitCalendar;
use App\Modules\Health\Models\Measurement;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final readonly class MeasurementService
{
    public function __construct(private HealthSettings $settings) {}

    /**
     * Stores weigh-ins read from the scale. The same weigh-in arrives first live (no composition)
     * and later from the scale's history (with its own clock and the composition), so both copies
     * are matched by weight and impedances and merged into one row.
     *
     * @param  list<array<string, mixed>>  $readings
     * @return array{created: int, updated: int}
     */
    public function sync(User $user, array $readings): array
    {
        $created = 0;
        $updated = 0;

        DB::transaction(function () use ($user, $readings, &$created, &$updated): void {
            foreach ($readings as $reading) {
                $fingerprint = self::fingerprint((float) $reading['weight_kg'], $reading['impedances'] ?? null);
                $measurement = Measurement::query()->ownedBy($user)->where('fingerprint', $fingerprint)->first();

                if ($measurement === null) {
                    $measurement = new Measurement(['source' => 'scale', 'fingerprint' => $fingerprint]);
                    $measurement->user_id = $user->id;
                    $this->fill($measurement, $reading);
                    $measurement->save();
                    $created++;

                    continue;
                }

                $this->fill($measurement, $reading, merging: true);

                if ($measurement->isDirty()) {
                    $measurement->save();
                    $updated++;
                }
            }
        });

        return ['created' => $created, 'updated' => $updated];
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function store(User $user, array $data): Measurement
    {
        $measurement = new Measurement([
            'source' => 'manual',
            'measured_at' => isset($data['measured_at']) ? CarbonImmutable::parse((string) $data['measured_at']) : CarbonImmutable::now(),
            'weight_kg' => $data['weight_kg'],
            'fat_percent' => $data['fat_percent'] ?? null,
            'muscle_percent' => $data['muscle_percent'] ?? null,
            'water_percent' => $data['water_percent'] ?? null,
        ]);
        $measurement->user_id = $user->id;
        $measurement->bmi = $this->bmi($user, (float) $data['weight_kg']);
        $measurement->save();

        return $measurement;
    }

    /**
     * @return array<string, mixed>
     */
    public function summary(User $user): array
    {
        $latest = Measurement::query()->ownedBy($user)->latest('measured_at')->first();
        $settings = $this->settings->for($user);
        $goal = $settings['goal_kg'];

        return [
            'latest' => $latest,
            'latest_with_metrics' => Measurement::query()->ownedBy($user)->whereNotNull('fat_percent')->latest('measured_at')->first(),
            'change_7d' => $latest === null ? null : $this->changeSince($user, $latest, 7),
            'change_30d' => $latest === null ? null : $this->changeSince($user, $latest, 30),
            'goal_kg' => $goal,
            'to_goal_kg' => $latest === null || $goal === null ? null : round($latest->weight() - $goal, 2),
            'weighed_today' => $latest !== null && HabitCalendar::localDay($latest->measured_at)->equalTo(HabitCalendar::today()),
            'profile_complete' => $settings['height_cm'] !== null && $settings['age'] !== null && $settings['sex'] !== null,
        ];
    }

    public function weighedOn(User $user, CarbonImmutable $day): bool
    {
        $start = HabitCalendar::date($day);

        return Measurement::query()->ownedBy($user)
            ->where('measured_at', '>=', $start)
            ->where('measured_at', '<', $start->addDay())
            ->exists();
    }

    /**
     * @param  mixed  $impedances
     */
    public static function fingerprint(float $kg, $impedances): string
    {
        $values = is_array($impedances) ? array_map('intval', array_values($impedances)) : [];

        return hash('sha256', number_format($kg, 2, '.', '').'|'.implode(',', $values));
    }

    /**
     * @param  array<string, mixed>  $reading
     */
    private function fill(Measurement $measurement, array $reading, bool $merging = false): void
    {
        $stored = ($reading['stored'] ?? false) === true;

        // The scale's own clock dates a stored reading; a live one is dated by the phone.
        if (! $merging || $stored) {
            $measurement->measured_at = CarbonImmutable::parse((string) $reading['measured_at']);
        }

        $measurement->weight_kg = number_format((float) $reading['weight_kg'], 2, '.', '');
        $measurement->impedances ??= isset($reading['impedances']) ? array_map('intval', $reading['impedances']) : null;
        $measurement->frames ??= $reading['frames'] ?? null;
        $measurement->device ??= $reading['device'] ?? null;
        $measurement->firmware ??= $reading['firmware'] ?? null;

        if (isset($reading['metrics']) && is_array($reading['metrics'])) {
            foreach (Measurement::METRICS as $key) {
                if (array_key_exists($key, $reading['metrics'])) {
                    $measurement->setAttribute($key, $reading['metrics'][$key]);
                }
            }
            $measurement->metrics_frame = $reading['metrics_frame'] ?? $measurement->metrics_frame;
        }
    }

    private function changeSince(User $user, Measurement $latest, int $days): ?float
    {
        $before = Measurement::query()->ownedBy($user)
            ->where('measured_at', '<=', $latest->measured_at->subDays($days))
            ->latest('measured_at')
            ->first();

        return $before === null ? null : round($latest->weight() - $before->weight(), 2);
    }

    private function bmi(User $user, float $kg): ?string
    {
        $height = $this->settings->for($user)['height_cm'];

        return $height === null ? null : number_format($kg / (($height / 100) ** 2), 1, '.', '');
    }
}
