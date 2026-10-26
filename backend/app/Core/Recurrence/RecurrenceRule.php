<?php

namespace App\Core\Recurrence;

use Carbon\CarbonImmutable;
use DateTimeImmutable;
use DateTimeZone;
use InvalidArgumentException;
use RRule\RRule;
use Throwable;

final readonly class RecurrenceRule
{
    public const string TIMEZONE = 'Europe/Madrid';

    private const array FREQUENCIES = ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'];

    private const array PARTS = ['FREQ', 'INTERVAL', 'BYDAY', 'BYMONTHDAY', 'BYMONTH', 'BYSETPOS'];

    private const int MAX_ITERATIONS = 1000;

    /**
     * @param  array<string, string>  $parts
     * @param  RRule<DateTimeImmutable>  $engine
     */
    private function __construct(
        public array $parts,
        public CarbonImmutable $start,
        public ?CarbonImmutable $until,
        public ?int $count,
        private RRule $engine,
    ) {}

    public static function parse(string $rule, CarbonImmutable $start, ?CarbonImmutable $until = null, ?int $count = null): self
    {
        $parts = self::split($rule);
        $start = self::day($start);

        $definition = $parts;
        $definition['DTSTART'] = new DateTimeImmutable($start->format('Y-m-d').' 00:00:00', new DateTimeZone(self::TIMEZONE));

        if ($until !== null) {
            $definition['UNTIL'] = new DateTimeImmutable(self::day($until)->format('Y-m-d').' 23:59:59', new DateTimeZone(self::TIMEZONE));
        }

        if ($count !== null) {
            $definition['COUNT'] = (string) $count;
        }

        try {
            $engine = new RRule($definition);
        } catch (Throwable $exception) {
            throw new InvalidArgumentException('La frecuencia no es válida: '.$exception->getMessage(), previous: $exception);
        }

        return new self($parts, $start, $until === null ? null : self::day($until), $count, $engine);
    }

    public static function isValid(string $rule): bool
    {
        try {
            self::parse($rule, CarbonImmutable::now(self::TIMEZONE));

            return true;
        } catch (InvalidArgumentException) {
            return false;
        }
    }

    /**
     * @return list<CarbonImmutable>
     */
    public function between(CarbonImmutable $from, CarbonImmutable $to): array
    {
        $from = self::day($from);
        $to = self::day($to);

        if ($to->lt($from)) {
            return [];
        }

        $dates = [];
        $seen = 0;
        foreach ($this->engine as $occurrence) {
            $date = self::day(CarbonImmutable::instance($occurrence));

            if ($date->gt($to) || count($dates) >= self::MAX_ITERATIONS || ++$seen > self::MAX_ITERATIONS * 20) {
                break;
            }

            if ($date->gte($from)) {
                $dates[] = $date;
            }
        }

        return $dates;
    }

    /**
     * @return list<CarbonImmutable>
     */
    public function next(CarbonImmutable $from, int $limit): array
    {
        $from = self::day($from);
        $dates = [];
        $seen = 0;

        foreach ($this->engine as $occurrence) {
            if (++$seen > self::MAX_ITERATIONS * 10) {
                break;
            }

            $date = self::day(CarbonImmutable::instance($occurrence));

            if ($date->gte($from)) {
                $dates[] = $date;
            }

            if (count($dates) >= $limit) {
                break;
            }
        }

        return $dates;
    }

    public function part(string $name): ?string
    {
        return $this->parts[$name] ?? null;
    }

    public function interval(): int
    {
        return max(1, (int) ($this->parts['INTERVAL'] ?? 1));
    }

    public function frequency(): string
    {
        return $this->parts['FREQ'];
    }

    public function toString(): string
    {
        return implode(';', array_map(fn (string $key, string $value) => "{$key}={$value}", array_keys($this->parts), $this->parts));
    }

    /**
     * @return array<string, string>
     */
    private static function split(string $rule): array
    {
        $rule = strtoupper(trim(preg_replace('/^RRULE:/i', '', trim($rule)) ?? ''));

        if ($rule === '') {
            throw new InvalidArgumentException('La frecuencia está vacía.');
        }

        $parts = [];
        foreach (explode(';', rtrim($rule, ';')) as $segment) {
            [$key, $value] = array_pad(explode('=', $segment, 2), 2, '');

            if (! in_array($key, self::PARTS, true) || $value === '' || isset($parts[$key])) {
                throw new InvalidArgumentException("La frecuencia no admite [{$segment}].");
            }

            $parts[$key] = $value;
        }

        if (! in_array($parts['FREQ'] ?? null, self::FREQUENCIES, true)) {
            throw new InvalidArgumentException('La frecuencia debe ser diaria, semanal, mensual o anual.');
        }

        if (isset($parts['INTERVAL']) && (! ctype_digit($parts['INTERVAL']) || (int) $parts['INTERVAL'] < 1 || (int) $parts['INTERVAL'] > 365)) {
            throw new InvalidArgumentException('El intervalo debe estar entre 1 y 365.');
        }

        $ordered = [];
        foreach (self::PARTS as $key) {
            if (isset($parts[$key])) {
                $ordered[$key] = $parts[$key];
            }
        }

        return $ordered;
    }

    private static function day(CarbonImmutable $date): CarbonImmutable
    {
        $day = CarbonImmutable::createFromFormat('!Y-m-d', $date->format('Y-m-d'), self::TIMEZONE);

        if (! $day instanceof CarbonImmutable) {
            throw new InvalidArgumentException('Fecha no válida.');
        }

        return $day;
    }
}
