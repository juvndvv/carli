<?php

namespace App\Core\Console;

use App\Actions\Fortify\CreateNewUser;
use Illuminate\Console\Command;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

use function Laravel\Prompts\password;
use function Laravel\Prompts\text;

class CreateUserCommand extends Command
{
    protected $signature = 'app:create-user
        {--name= : Display name}
        {--email= : Login email}
        {--password= : Plain password (prompted when omitted)}';

    protected $description = 'Create a user account (public registration is disabled)';

    public function handle(CreateNewUser $creator): int
    {
        $name = $this->stringOption('name') ?? ($this->input->isInteractive() ? text('Nombre', required: true) : null);
        $email = $this->stringOption('email') ?? ($this->input->isInteractive() ? text('Email', required: true) : null);
        $plainPassword = $this->stringOption('password') ?? ($this->input->isInteractive() ? password('Contraseña', required: true) : null);

        if ($name === null || $email === null || $plainPassword === null) {
            $this->components->error('The --name, --email and --password options are required in non-interactive mode.');

            return self::FAILURE;
        }

        try {
            $user = $creator->create([
                'name' => $name,
                'email' => Str::lower(trim($email)),
                'password' => $plainPassword,
                'password_confirmation' => $plainPassword,
            ]);
        } catch (ValidationException $exception) {
            foreach ($exception->validator->errors()->all() as $message) {
                $this->components->error($message);
            }

            return self::FAILURE;
        }

        $this->components->info("User {$user->email} created ({$user->id}).");

        return self::SUCCESS;
    }

    private function stringOption(string $key): ?string
    {
        $value = $this->option($key);

        return is_string($value) && $value !== '' ? $value : null;
    }
}
