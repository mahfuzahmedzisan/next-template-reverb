<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Health check
|--------------------------------------------------------------------------
|
| Used by Coolify / Traefik / Docker HEALTHCHECK to verify the container is
| alive. The Reverb WebSocket process itself listens on the same port, so a
| 200 here means the PHP runtime booted correctly.
|
*/

Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'service' => 'reverb-server',
        'timestamp' => now()->toIso8601String(),
    ]);
});

Route::get('/', function () {
    return response()->json([
        'service' => 'reverb-server',
        'message' => 'Laravel Reverb WebSocket server. Connect via /app/{key}.',
    ]);
});
