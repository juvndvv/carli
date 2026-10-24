<?php

$host = getenv('DB_HOST') ?: 'postgres';
$port = getenv('DB_PORT') ?: '5432';
$database = getenv('DB_DATABASE') ?: 'personal';
$username = getenv('DB_USERNAME') ?: 'personal';
$password = getenv('DB_PASSWORD') ?: '';
$timeoutSeconds = (int) (getenv('DB_WAIT_TIMEOUT') ?: 60);

$deadline = time() + $timeoutSeconds;
$dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s;connect_timeout=3', $host, $port, $database);

while (true) {
    try {
        new PDO($dsn, $username, $password, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        fwrite(STDOUT, "Database {$host}:{$port}/{$database} is ready.\n");
        exit(0);
    } catch (PDOException $exception) {
        if (time() >= $deadline) {
            fwrite(STDERR, "ERROR: database {$host}:{$port}/{$database} not reachable after {$timeoutSeconds}s: {$exception->getMessage()}\n");
            exit(1);
        }
        fwrite(STDOUT, "Waiting for database {$host}:{$port}...\n");
        sleep(2);
    }
}
