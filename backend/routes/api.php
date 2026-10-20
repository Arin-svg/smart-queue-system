<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\AppointmentController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\QueueController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\WorkspaceController;
use App\Http\Middleware\EnsureActiveUser;
use Illuminate\Support\Facades\Route;

Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
Route::middleware(['auth:sanctum', EnsureActiveUser::class])->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/push/device', [\App\Http\Controllers\PushDeviceController::class, 'store'])->middleware('throttle:20,1');
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/workspace', [WorkspaceController::class, 'index']);
    Route::post('/ai/chat', [\App\Http\Controllers\AiChatController::class, 'reply'])->middleware('throttle:10,1');
    Route::post('/notifications/{id}/read', [WorkspaceController::class, 'readNotification']);
    Route::post('/notifications/read', [WorkspaceController::class, 'readNotifications']);
    Route::get('/clinic/qr', [QueueController::class, 'qr']);
    Route::post('/clinic/qr', [QueueController::class, 'replaceQr']);
    Route::post('/clinic/qr/validate', [QueueController::class, 'validateQr']);
    Route::post('/queues', [QueueController::class, 'store']);
    Route::post('/queues/{id}', [QueueController::class, 'update']);
    Route::get('/appointments/slots', [AppointmentController::class, 'slots']);
    Route::post('/appointments', [AppointmentController::class, 'store']);
    Route::post('/appointments/{id}/verify', [AppointmentController::class, 'verify']);
    Route::post('/appointments/{id}/cancel', [AppointmentController::class, 'cancel']);
    Route::post('/admin/users/import/preview', [\App\Http\Controllers\UserImportController::class, 'preview']);
    Route::post('/admin/users/{id?}', [AdminController::class, 'user'])->whereNumber('id');
    Route::post('/admin/departments/{id?}', [AdminController::class, 'department']);
    Route::post('/admin/rooms/{id?}', [AdminController::class, 'room']);
    Route::post('/admin/settings', [AdminController::class, 'settings']);
    Route::get('/reports', [ReportController::class, 'index']);
    Route::post('/profile', [ProfileController::class, 'update']);
    Route::post('/profile/password', [ProfileController::class, 'password']);
});
