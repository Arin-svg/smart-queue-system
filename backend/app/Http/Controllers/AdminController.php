<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Notifications\TemporaryPassword;
use App\Services\Clinic;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Support\Str;

class AdminController extends Controller
{
    public function user(Request $request, ?int $id = null)
    {
        Clinic::roles($request->user(), ['administrator']);
        $data = $request->validate([
            'name' => 'required|string|max:100', 'user_identifier' => ['required', 'string', 'max:50', Rule::unique('users', 'user_identifier')->ignore($id, 'user_id')],
            'email' => ['required', 'email', 'max:100', Rule::unique('users', 'email')->ignore($id, 'user_id')],
            'phone_no' => 'nullable|string|max:20', 'role_id' => 'required|integer|exists:roles,role_id',
            'status' => 'required|in:active,inactive', 'password' => 'prohibited',
        ]);

        if (! $id && in_array(config('mail.default'), ['log', 'array'])) {
            return response()->json(['message' => 'Account email is not configured. Configure email delivery before adding users.'], 503);
        }

        return DB::transaction(function () use ($request, $id, $data) {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            $user = $id ? User::findOrFail($id) : new User;
            $changedRole = $id && $user->role_id != $data['role_id'];
            if ($id && ($changedRole || $data['status'] === 'inactive')) {
                if ($id === $request->user()->user_id) {
                    Clinic::fail('You cannot disable or change the role of your own account.');
                }
                if (DB::table('queues')->whereIn('queue_status', Clinic::ACTIVE)->where(fn ($q) => $q->where('user_id', $id)->orWhere('doctor_id', $id))->exists()) {
                    Clinic::fail('Finish or reassign this account\'s active queues first.');
                }
                if (DB::table('rooms')->where('doctor_id', $id)->exists()) {
                    Clinic::fail('Remove this doctor from assigned rooms first.');
                }
                if (DB::table('appointments')->whereIn('appointment_status', ['pending', 'confirmed'])->where(fn ($q) => $q->where('user_id', $id)->orWhere('doctor_id', $id))->exists()) {
                    Clinic::fail('Resolve this account\'s appointments first.');
                }
            }
            unset($data['password']);
            if (! $id) {
                $temporaryPassword = Str::password(16);
                $data['password'] = $temporaryPassword;
            }
            $user->fill($data)->save();
            if ($id && ($changedRole || $data['status'] === 'inactive')) {
                $user->tokens()->delete();
            }
            Clinic::log($request->user(), $id ? 'update_user' : 'create_user', 'user', $user->user_id);

            if (! $id) {
                try {
                    $user->notify(new TemporaryPassword($temporaryPassword));
                } catch (\Throwable $exception) {
                    // Roll back creation so the administrator can retry safely.
                    abort(503, 'Account email could not be sent. The user was not created. Check email delivery and try again.');
                }
            }

            return ['message' => $id ? 'User saved.' : 'User created. A temporary password has been sent by email.'];
        });
    }

    public function department(Request $request, ?int $id = null)
    {
        Clinic::roles($request->user(), ['administrator']);
        $data = $request->validate([
            'department_name' => ['required', 'string', 'max:100', Rule::unique('departments', 'department_name')->ignore($id, 'department_id')],
            'department_code' => ['required', 'alpha_dash', 'max:12', Rule::unique('departments', 'department_code')->ignore($id, 'department_id')],
            'description' => 'nullable|string|max:255', 'status' => 'required|in:active,inactive',
        ]);

        return DB::transaction(function () use ($request, $id, $data) {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            if ($id) {
                abort_unless(DB::table('departments')->where('department_id', $id)->exists(), 404);
            }
            if ($id && $data['status'] === 'inactive' &&
                (DB::table('queues')->where('department_id', $id)->whereIn('queue_status', Clinic::ACTIVE)->exists() ||
                 DB::table('appointments')->where('department_id', $id)->whereIn('appointment_status', ['pending', 'confirmed'])->exists())) {
                Clinic::fail('Resolve active queues and appointments before disabling this department.');
            }
            if ($id) {
                DB::table('departments')->where('department_id', $id)->update($data + ['updated_at' => now()]);
            } else {
                $id = DB::table('departments')->insertGetId($data + ['created_at' => now(), 'updated_at' => now()], 'department_id');
            }
            Clinic::log($request->user(), 'save_department', 'department', $id);

            return ['message' => 'Department saved.'];
        });
    }

    public function room(Request $request, ?int $id = null)
    {
        Clinic::roles($request->user(), ['administrator']);
        $data = $request->validate(['room_name' => ['required', 'string', 'max:100', Rule::unique('rooms', 'room_name')->where('department_id', $request->input('department_id'))->ignore($id, 'room_id')],
            'room_number' => 'nullable|string|max:30',
            'department_id' => 'required|integer|exists:departments,department_id', 'doctor_id' => 'nullable|integer|exists:users,user_id', 'status' => 'required|in:available,unavailable,inactive']);

        return DB::transaction(function () use ($request, $id, $data) {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            if ($id) {
                abort_unless(DB::table('rooms')->where('room_id', $id)->exists(), 404);
            }
            if ($id && DB::table('queues')->where('room_id', $id)->whereIn('queue_status', Clinic::ACTIVE)->exists()) {
                Clinic::fail('Resolve the room\'s active queues before changing it.');
            }
            if (! DB::table('departments')->where('department_id', $data['department_id'])->where('status', 'active')->exists()) {
                Clinic::fail('Select an active department.');
            }
            if (! empty($data['doctor_id'])) {
                $doc = User::with('role')->findOrFail($data['doctor_id']);
                if ($doc->status !== 'active' || $doc->role->role_name !== 'doctor') {
                    Clinic::fail('Select an active doctor.');
                }
            }
            if ($id) {
                DB::table('rooms')->where('room_id', $id)->update($data + ['updated_at' => now()]);
            } else {
                $id = DB::table('rooms')->insertGetId($data + ['created_at' => now(), 'updated_at' => now()], 'room_id');
            }
            Clinic::log($request->user(), 'save_room', 'room', $id);

            return ['message' => 'Room saved.'];
        });
    }

    public function settings(Request $request)
    {
        Clinic::roles($request->user(), ['administrator']);
        $data = $request->validate(['average_minutes' => 'required|integer|min:1|max:120', 'slot_minutes' => 'required|integer|min:5|max:120',
            'opening_time' => 'required|date_format:H:i', 'closing_time' => 'required|date_format:H:i|after:opening_time',
            'slot_capacity' => 'required|integer|min:1|max:100', 'registration_open' => 'required|boolean']);
        DB::transaction(function () use ($request, $data) {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            DB::table('clinic_settings')->where('id',1)->update($data);
            Clinic::log($request->user(),'update_settings','clinic');
        });

        return ['message' => 'Queue settings saved.'];
    }
}
