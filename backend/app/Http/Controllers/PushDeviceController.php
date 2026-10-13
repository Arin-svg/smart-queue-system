<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Crypt;
class PushDeviceController extends Controller {
 public function store(Request $request) {
  $data=$request->validate(['token'=>'required|string|max:4096']);
  $hash=hash('sha256',$data['token']);
  DB::transaction(function() use($request,$data,$hash) {
   $old=DB::table('push_devices')->where('token_hash',$hash)->lockForUpdate()->first();
   $same=$old && $old->user_id == $request->user()->user_id;
   DB::table('push_devices')->updateOrInsert(['token_hash'=>$hash],[
    'user_id'=>$request->user()->user_id,'access_token_id'=>$request->user()->currentAccessToken()->id,
    'token'=>Crypt::encryptString($data['token']),
    'last_notification_id'=>$same ? $old->last_notification_id : (DB::table('notifications')->max('notification_id') ?? 0),
    'created_at'=>$old->created_at ?? now(),'updated_at'=>now(),
   ]);
  });
  return ['message'=>'Device notifications registered.'];
 }
}
