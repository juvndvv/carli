<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Parallel testing only switches the default connection to its per-process
        // database; keep the cache lock connection on that same database.
        $database = config('database.connections.pgsql.database');

        if (config('database.connections.pgsql_locks.database') !== $database) {
            config(['database.connections.pgsql_locks.database' => $database]);
            DB::purge('pgsql_locks');
        }
    }
}
