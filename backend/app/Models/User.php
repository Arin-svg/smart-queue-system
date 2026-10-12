<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens;
    use Notifiable;

    protected $primaryKey = 'user_id';

    protected $fillable = ['role_id', 'user_identifier', 'name', 'email', 'phone_no', 'password', 'status'];

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
            'name' => $this->name, 'email' => $this->email, 'phone_no' => $this->phone_no, 'role' => $this->role->role_name];
    }
}
