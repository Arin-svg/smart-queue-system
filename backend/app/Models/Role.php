<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Role extends Model
{
    protected $primaryKey = 'role_id';

    public $timestamps = false;

    protected $fillable = ['role_name'];
}
