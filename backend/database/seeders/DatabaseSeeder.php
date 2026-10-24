<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public const string DEMO_EMAIL = 'demo@example.com';

    public const string DEMO_PASSWORD = 'password';

    public function run(): void
    {
        $seedDemo = (bool) config('app.seed_demo_user');

        if ($seedDemo) {
            User::query()->firstOrCreate(
                ['email' => self::DEMO_EMAIL],
                ['name' => 'Demo', 'password' => self::DEMO_PASSWORD],
            );
        }

        foreach ($this->moduleSeeders($seedDemo) as $seeder) {
            $this->call($seeder);
        }
    }

    /**
     * @return list<class-string<Seeder>>
     */
    private function moduleSeeders(bool $includeDemo): array
    {
        $seeders = [];

        foreach ((array) config('modules.providers', []) as $provider) {
            if (! is_string($provider)) {
                continue;
            }

            $namespace = Str::beforeLast($provider, '\\');
            $module = Str::afterLast($namespace, '\\');
            $suffixes = $includeDemo ? ['DatabaseSeeder', 'Seeder', 'DemoSeeder'] : ['DatabaseSeeder', 'Seeder'];

            foreach ($suffixes as $suffix) {
                $class = "{$namespace}\\database\\seeders\\{$module}{$suffix}";

                if (class_exists($class) && is_subclass_of($class, Seeder::class)) {
                    $seeders[] = $class;
                }
            }
        }

        return $seeders;
    }
}
