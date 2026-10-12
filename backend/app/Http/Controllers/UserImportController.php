<?php

namespace App\Http\Controllers;

use App\Services\Clinic;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class UserImportController extends Controller
{
    public function preview(Request $request)
    {
        Clinic::roles($request->user(), ['administrator']);
        $input = $request->validate([
            'rows' => 'required|array|min:1|max:500',
            'rows.*' => 'required|array',
            'rows.*.row' => 'required|integer|min:2|max:10000',
            'rows.*.name' => 'nullable|string|max:500',
            'rows.*.email' => 'nullable|string|max:500',
            'rows.*.user_identifier' => 'nullable|string|max:500',
            'rows.*.phone_no' => 'nullable|string|max:500',
            'rows.*.role' => 'nullable|string|max:100',
            'rows.*.status' => 'nullable|string|max:100',
        ]);
        $roles = DB::table('roles')->pluck('role_id', 'role_name');
        $existingEmails = DB::table('users')->pluck('email')->map(fn ($v) => mb_strtolower(trim($v)))->flip();
        $existingIds = DB::table('users')->pluck('user_identifier')->map(fn ($v) => mb_strtolower(trim($v)))->flip();
        $emails = [];
        $ids = [];
        $rows = [];
        foreach ($input['rows'] as $source) {
            $role = strtolower(trim($source['role'] ?? '')) ?: 'patient';
            $data = [
                'name' => trim($source['name'] ?? ''),
                'email' => strtolower(trim($source['email'] ?? '')),
                'user_identifier' => trim($source['user_identifier'] ?? ''),
                'phone_no' => trim($source['phone_no'] ?? ''),
                'role_id' => $roles[$role] ?? null,
                'status' => strtolower(trim($source['status'] ?? '')) ?: 'active',
            ];
            $validator = Validator::make($data, [
                'name' => 'required|string|max:100', 'email' => 'required|email|max:100',
                'user_identifier' => 'required|string|max:50', 'phone_no' => 'nullable|string|max:20',
                'role_id' => 'required|integer', 'status' => 'required|in:active,inactive',
            ]);
            $status = 'ready';
            $message = 'Ready to create and email.';
            $email = $data['email'];
            $identifier = mb_strtolower($data['user_identifier']);
            if ($validator->fails() || ! in_array($role, ['patient', 'staff', 'doctor', 'administrator'])) {
                $status = 'invalid';
                $message = $validator->fails() ? $validator->errors()->first() : 'Unknown role.';
            } elseif ($existingEmails->has($email) || $existingIds->has($identifier)) {
                $status = 'existing';
                $message = 'Email or ID already exists. Existing account will not be changed.';
            } elseif (isset($emails[$email]) || isset($ids[$identifier])) {
                $status = 'duplicate';
                $message = 'Repeated email or ID in this file.';
            } else {
                $emails[$email] = true;
                $ids[$identifier] = true;
            }
            $rows[] = ['row' => $source['row'], 'data' => $data, 'role' => $role, 'status' => $status, 'message' => $message];
        }

        return ['rows' => $rows];
    }
}
