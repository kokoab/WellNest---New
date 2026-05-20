<?php

namespace Tests\Feature\ApiRoutes;

use Tests\Support\ApiRouteDoubleTestCase;

class MessagingApiRouteDoubleTest extends ApiRouteDoubleTestCase
{
    protected static function routeKeys(): array
    {
        return [
            'GET_conversations_assistant',
            'GET_conversations_unread_count',
            'GET_conversations',
            'GET_conversations_show',
            'POST_conversations',
            'PUT_conversations',
            'DELETE_conversations',
            'GET_conversations_messages',
            'POST_conversations_messages',
            'PATCH_conversations_messages_read',
            'GET_messages',
            'GET_messages_show',
            'POST_messages',
            'PUT_messages',
            'DELETE_messages',
            'PATCH_messages_read',
            'POST_messages_attachments',
            'GET_message_attachments',
            'GET_message_attachments_show',
            'POST_message_attachments',
            'PUT_message_attachments',
            'DELETE_message_attachments',
        ];
    }
}
