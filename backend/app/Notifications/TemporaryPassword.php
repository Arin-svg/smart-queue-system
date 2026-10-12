<?php

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class TemporaryPassword extends Notification
{
    public function __construct(public readonly string $temporaryPassword) {}

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Your Smart Queue System account')
            ->greeting('Hello '.$notifiable->name.',')
            ->line('Your clinic administrator has created your Smart Queue System account.')
            ->line('User ID: '.$notifiable->user_identifier)
            ->line('Temporary password: '.$this->temporaryPassword)
            ->line('Sign in to the Smart Queue System app, then change this password from your profile.')
            ->line('Keep your password private.');
    }
}
