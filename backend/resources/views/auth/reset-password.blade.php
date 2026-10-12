<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SQS · Reset Password</title>
<style>body{margin:0;background:#f7f7fc;font:16px Arial,sans-serif;color:#233534}header{background:#00b98e;padding:64px 24px;text-align:center;color:white}main{max-width:420px;margin:32px auto;background:white;border-radius:18px;padding:28px}label{display:block;margin:18px 0 8px}input{box-sizing:border-box;width:100%;padding:14px;border:1px solid #dde3e2;border-radius:10px}button{width:100%;padding:14px;margin-top:24px;border:0;border-radius:10px;background:#009b8f;color:white;font-weight:bold}.error{color:#b32d2d}</style></head>
<body><header><h1>Smart Queue System</h1></header><main><h2>Reset Password</h2>
@if(session('status'))<p role="status">{{ session('status') }}</p>
@else
@foreach($errors->all() as $error)<p class="error" role="alert">{{ $error }}</p>@endforeach
<form method="post" action="{{ route('password.update') }}">@csrf
<input type="hidden" name="token" value="{{ $token }}">
<label for="email">Email</label><input id="email" type="email" name="email" value="{{ $email }}" required autocomplete="email">
<label for="password">New Password</label><input id="password" type="password" name="password" minlength="8" maxlength="255" required autocomplete="new-password">
<label for="confirmation">Confirm New Password</label><input id="confirmation" type="password" name="password_confirmation" minlength="8" required autocomplete="new-password">
<button type="submit">Update Password</button></form>
@endif
</main></body></html>
