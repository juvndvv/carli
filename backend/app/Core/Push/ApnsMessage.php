<?php

namespace App\Core\Push;

final readonly class ApnsMessage
{
    public function __construct(
        public string $title,
        public string $body,
        public ?string $url = null,
        public ?string $threadId = null,
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function payload(): array
    {
        $aps = [
            'alert' => ['title' => $this->title, 'body' => $this->body],
            'sound' => 'default',
        ];

        if ($this->threadId !== null) {
            $aps['thread-id'] = $this->threadId;
        }

        return array_filter(['aps' => $aps, 'url' => $this->url], fn ($value) => $value !== null);
    }
}
