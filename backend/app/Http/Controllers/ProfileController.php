<?php

namespace App\Http\Controllers;

use App\Services\Clinic;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class ProfileController extends Controller
{
    public function update(Request $request)
    {
        Clinic::roles($request->user(), ['patient']);
        $data = $request->validate(['phone_no' => 'nullable|string|max:20']);
        $request->user()->update($data);
        Clinic::log($request->user(), 'update_profile', 'user', $request->user()->user_id);

        return ['message' => 'Profile updated.', 'user' => $request->user()->profile()];
    }

    public function password(Request $request)
    {
        $data = $request->validate(['current_password' => 'required|string', 'password' => 'required|string|min:8|max:255|confirmed|different:current_password']);
        if (! Hash::check($data['current_password'], $request->user()->password)) {
            Clinic::fail('Your current password is incorrect.');
        }
        DB::transaction(function () use ($request, $data) {
            $request->user()->update(['password' => $data['password']]);
            $request->user()->tokens()->where('id', '!=', $request->user()->currentAccessToken()->id)->delete();
            Clinic::log($request->user(), 'change_password', 'user', $request->user()->user_id);
        });

        return ['message' => 'Password changed. Other sessions have been signed out.'];
    }
}
