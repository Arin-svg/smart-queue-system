<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class EnsureActiveUser
{
    public function handle(Request $request, Closure $next)
    {
        if ($request->user()?->status !== 'active') {
            $request->user()?->currentAccessToken()?->delete();

            return response()->json(['message' => 'This account is inactive.'], 403);
        }

        return $next($request);
    }
}
