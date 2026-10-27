<?php

namespace App\Modules\Tasks\Domain\Conversion;

use Carbon\CarbonImmutable;

final readonly class TemplateHistory
{
    public const string DONE = 'done';

    public const string SKIPPED = 'skipped';

    public const string MISSED = 'missed';

    /**
     * @param  array<string, string>  $occurrences  date (Y-m-d) => done|skipped|missed
     */
    public function __construct(
        public string $templateId,
        public string $title,
        public ?string $rrule,
        public CarbonImmutable $dtstart,
        public bool $afterDone,
        public bool $paused,
        public array $occurrences,
    ) {}

    public function firstDate(): ?string
    {
        $dates = array_keys($this->occurrences);
        sort($dates);

        return $dates[0] ?? null;
    }
}
