<?php

namespace App\Modules\Health\Http\Controllers;

use App\Modules\Health\Jobs\ApplyWhoopEventJob;
use App\Modules\Health\Models\WhoopAccount;
use App\Modules\Health\Whoop\WhoopClient;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;

/**
 * WHOOP posts here when a sleep, recovery or workout changes. The body only carries ids, so the record is fetched
 * in a job; WHOOP retries for an hour on anything but 2xx and may send the same event twice.
 */
final class WhoopWebhookController
{
    /** @var list<string> */
    public const array TYPES = ['sleep.updated', 'sleep.deleted', 'recovery.updated', 'recovery.deleted', 'workout.updated', 'workout.deleted'];

    public function __invoke(Request $request, WhoopClient $whoop): Response
    {
        if (! $whoop->validSignature($request->getContent(), $request->header('X-WHOOP-Signature-Timestamp'), $request->header('X-WHOOP-Signature'))) {
            return response()->noContent(401);
        }

        $memberId = $request->json('user_id');
        $id = $request->json('id');
        $type = $request->json('type');
        $traceId = $request->json('trace_id');

        if (! is_int($memberId) || ! (is_string($id) || is_int($id)) || ! in_array($type, self::TYPES, true)) {
            // Nothing carli reads: acknowledge so WHOOP does not retry.
            return response()->noContent();
        }

        $account = WhoopAccount::query()->where('whoop_user_id', $memberId)->first();

        if ($account === null || (is_string($traceId) && ! Cache::add('health:whoop:trace:'.$traceId, true, now()->addDay()))) {
            return response()->noContent();
        }

        ApplyWhoopEventJob::dispatch($account->id, $type, (string) $id);

        return response()->noContent();
    }
}
