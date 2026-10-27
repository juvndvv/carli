<?php

namespace App\Core\Push;

final readonly class ApnsMessage
{
    public function __construct(
        public string $title,
        public string $body,
        public ?string $url = null,
        public ?string $threadId = null,
        public ?string $notificationId = null,
    ) {}

    public function withNotificationId(?string $notificationId): self
    {
        return new self($this->title, $this->body, $this->url, $this->threadId, $notificationId);
    }

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

        return array_filter(
            ['aps' => $aps, 'url' => $this->url, 'notification_id' => $this->notificationId],
            fn ($value) => $value !== null,
        );
    }
}
