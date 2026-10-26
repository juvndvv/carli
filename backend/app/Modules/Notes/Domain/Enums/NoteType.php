<?php

namespace App\Modules\Notes\Domain\Enums;

enum NoteType: string
{
    case Text = 'text';

    case List = 'list';

    case Shopping = 'shopping';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_map(fn (self $case) => $case->value, self::cases());
    }

    public function label(): string
    {
        return match ($this) {
            self::Text => 'Texto',
            self::List => 'Lista',
            self::Shopping => 'Compra',
        };
    }

    public function icon(): string
    {
        return match ($this) {
            self::Text => 'notebook-pen',
            self::List => 'list-checks',
            self::Shopping => 'shopping-cart',
        };
    }

    public function canBecome(self $type): bool
    {
        return $this === $type || ($this !== self::Shopping && $type !== self::Shopping);
    }
}
