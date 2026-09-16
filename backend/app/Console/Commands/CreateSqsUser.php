<?php

namespace App\Console\Commands;

use App\Models\Role;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;

class CreateSqsUser extends Command
{
    protected $signature = 'sqs:create-user';

    protected $description = 'Create an SQS account with a securely hashed password';

    public function handle(): int
    {
        $data = [
            'user_identifier' => $this->ask('User ID (e.g. CB23094)'),
            'name' => $this->ask('Full name'),
            'email' => $this->ask('Email'),
            'role' => $this->choice('Role', ['patient', 'staff', 'doctor', 'administrator']),
            'password' => $this->secret('Password (at least 8 characters)'),
            'password_confirmation' => $this->secret('Confirm password'),
        ];
        $validator = Validator::make($data, [
            'user_identifier' => ['required', 'string', 'max:50', 'unique:users,user_identifier'],
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:100', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'max:255', 'confirmed'],
        ]);
        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }
        $role = Role::where('role_name', $data['role'])->firstOrFail();
        User::create([
            'role_id' => $role->role_id, 'user_identifier' => $data['user_identifier'],
            'name' => $data['name'], 'email' => $data['email'],
            'password' => $data['password'], 'status' => 'active',
        ]);
        $this->info('Account created. You can now log in from Flutter.');

        return self::SUCCESS;
    }
}
