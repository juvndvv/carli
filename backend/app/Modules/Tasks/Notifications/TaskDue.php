<?php

namespace App\Modules\Tasks\Notifications;

use App\Core\Notifications\NotificationChannels;
use App\Core\Push\ApnsMessage;
use App\Core\Push\ApnsNotification;
use App\Models\User;
use App\Modules\Tasks\Domain\Services\TasksSettings;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

/**
 * The push at a task's due time.
 */
final class TaskDue extends Notification implements ApnsNotification, ShouldQueue
{
    use Queueable;

    public const string TYPE = 'task_due';

    public function __construct(
        public readonly string $taskId,
        public readonly string $title,
        public readonly string $time,
        public readonly ?string $list = null,
    ) {}

    /**
     * @return list<string>
     */
    public function via(User $notifiable): array
    {
        return NotificationChannels::for($notifiable, TasksSettings::MODULE, self::TYPE);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(User $notifiable): array
    {
        return [
            'module' => TasksSettings::MODULE,
            'type' => self::TYPE,
            'title' => $this->title,
            'body' => $this->body(),
            'url' => $this->url(),
        ];
    }

    public function toApns(User $notifiable): ApnsMessage
    {
        return new ApnsMessage(
            title: $this->title,
            body: $this->body(),
            url: $this->url(),
            threadId: TasksSettings::MODULE.'.'.self::TYPE,
        );
    }

    private function url(): string
    {
        return '/tareas/tarea/'.$this->taskId;
    }

    private function body(): string
    {
        return $this->list === null ? "Tarea para las {$this->time}" : "Tarea para las {$this->time} · {$this->list}";
    }
}
