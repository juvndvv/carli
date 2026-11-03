<?php

it('serves the public home and privacy pages for the Google consent screen', function () {
    $this->get('/api/v1/legal')->assertOk()->assertSee('carli');
    $this->get('/api/v1/legal/privacidad')
        ->assertOk()
        ->assertSee('calendar.readonly')
        ->assertSee('uso limitado')
        ->assertDontSee('Política de privacidad</a>', false);
});
