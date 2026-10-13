<?php
namespace App\Services;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
class FirebasePush {
 protected function credentials(): array {
  return json_decode(file_get_contents(storage_path('app/firebase-service-account.json')),true,512,JSON_THROW_ON_ERROR);
 }
 public function deliver(): int {
  $credentials=$this->credentials();
  $access=Cache::remember('firebase.push.access',3000, function() use($credentials) {
   $auth=new ServiceAccountCredentials('https://www.googleapis.com/auth/firebase.messaging',$credentials);
   $token=$auth->fetchAuthToken();
   if(empty($token['access_token'])) throw new \RuntimeException('Firebase authentication failed');
   return $token['access_token'];
  });
  $sent=0;
  foreach(DB::table('push_devices')->get() as $device) {
   $session=DB::table('personal_access_tokens')->where('id',$device->access_token_id)->where('tokenable_id',$device->user_id)->first();
   if(!$session || ($session->expires_at && \Carbon\Carbon::parse($session->expires_at)->isPast()) || !DB::table('users')->where('user_id',$device->user_id)->where('status','active')->exists()) {
    DB::table('push_devices')->where('id',$device->id)->delete(); continue;
   }
   foreach(DB::table('notifications')->where('user_id',$device->user_id)->where('notification_id','>',$device->last_notification_id)->orderBy('notification_id')->limit(50)->get() as $n) {
    $r=Http::withToken($access)->connectTimeout(5)->timeout(15)->post('https://fcm.googleapis.com/v1/projects/'.rawurlencode($credentials['project_id']).'/messages:send', ['message'=>[
     'token'=>Crypt::decryptString($device->token),
     'notification'=>['title'=>$n->notification_title,'body'=>$n->notification_message],
     'data'=>['destination'=>$n->queue_id ? 'My Queue' : 'Alerts','user_id'=>(string)$device->user_id,'notification_id'=>(string)$n->notification_id],
     'android'=>['priority'=>'high','ttl'=>'300s','notification'=>['channel_id'=>'sqs_updates','tag'=>$n->queue_id ? 'queue-'.$n->queue_id : 'alert-'.$n->notification_id]],
    ]]);
    if(!$r->successful()) {
     $codes=collect($r->json('error.details',[]))->pluck('errorCode');
     if($codes->contains('UNREGISTERED')) DB::table('push_devices')->where('id',$device->id)->delete();
     if($r->status()===401) Cache::forget('firebase.push.access');
     throw new \RuntimeException('Firebase delivery returned HTTP '.$r->status());
    }
    DB::table('push_devices')->where('id',$device->id)->where('access_token_id',$device->access_token_id)->update(['last_notification_id'=>$n->notification_id]);
    $sent++;
   }
  }
  return $sent;
 }
}
