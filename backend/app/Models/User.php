<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens;

    protected $primaryKey = 'user_id';

    protected $fillable = ['role_id', 'user_identifier', 'name', 'email', 'password', 'status'];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return ['password' => 'hashed'];
    }

    public function role()
    {
        return $this->belongsTo(Role::class, 'role_id', 'role_id');
    }

    public function profile(): array
    {
        return ['id' => $this->user_id, 'user_identifier' => $this->user_identifier,
            'name' => $this->name, 'email' => $this->email, 'role' => $this->role->role_name];
    }
}
