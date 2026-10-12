<?php

use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/reset-password/{token}', function (Request $request, string $token) {
    return response()->view('auth.reset-password', ['token' => $token, 'email' => $request->query('email', '')])
        ->header('Referrer-Policy', 'no-referrer')->header('Cache-Control', 'no-store');
})->name('password.reset');

Route::post('/reset-password', function (Request $request) {
    $data = $request->validate(['token' => 'required|string', 'email' => 'required|email', 'password' => 'required|string|min:8|max:255|confirmed']);
    $status = Password::reset($data + ['status' => 'active'], function ($user, $password) {
        DB::transaction(function () use ($user, $password) {
            $user->forceFill(['password' => $password, 'remember_token' => Str::random(60)])->save();
            $user->tokens()->delete();
        });
        event(new PasswordReset($user));
    });

    return $status === Password::PASSWORD_RESET
        ? back()->with('status', 'Password updated. Return to SQS and sign in with your new password.')
        : back()->withErrors(['email' => 'This reset link is invalid or expired. Request a new one.']);
})->middleware('throttle:5,1')->name('password.update');
