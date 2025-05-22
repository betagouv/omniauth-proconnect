# Omniauth::Proconnect

Une stratégie pour [OmniAuth](https://github.com/omniauth/omniauth)
qui permet d'intégrer [ProConnect](https://www.proconnect.gouv.fr/).

## Pourquoi pas `omniauth_openid_connect` ?

ProConnect comporte quelques particularités comme le retour des
informations utilisateurs (`/userinfo`) en JWT et l'obligation
d'intégrer le `id_token_hint` dans l'URL de fin de session quand la
spec officielle le décrit optionnel.

Ces spécificités empêchent pour le moment d'utiliser la librairie
générique
[`omniauth_openid_connect`](https://github.com/omniauth/omniauth_openid_connect)
qui malgré son degré de maturité supérieure semble à l'abandon aussi.

## Utilisation

Une fois que vous avez créé votre application sur [l'espace
partenaires de
ProConnect](https://partenaires.proconnect.gouv.fr/apps) et identifié
vos endpoints grâce à leur [documentation
technique](https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique))
:

1. installer la gem `bundle add omniauth-proconnect` ;
2. configurer une nouvelle stratégie pour OmniAuth :

```ruby
# config/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider(
    :proconnect,
    {
      client_id: ENV.fetch("YOUR_APP_PC_CLIENT_ID"),
      client_secret: ENV.fetch("YOUR_APP_PC_CLIENT_SECRET"),
      proconnect_domain: ENV.fetch("YOUR_APP_PC_HOST"),
      redirect_uri: ENV.fetch("YOUR_APP_PC_REDIRECT_URI"),
      post_logout_redirect_uri: ENV.fetch("YOUR_APP_PC_POST_LOGOUT_REDIRECT_URI"),
      scope: ENV.fetch("YOUR_APP_PC_SCOPES")
    }
  )
end
```

3. envoyez votre utilisateur sur la stratégie :

```erb
<%= button_to "Se connecter via ProConnect", "/auth/proconnect", method: :post, remote: false, data: { turbo: false } %>
```

4. (optionnel) proposez la déconnexion aussi : le middleware observe
   le chemin de la page courante et déclenchera le processus de fin de
   session s'il se trouve sur `{request_path}/logout`, donc
   `/auth/proconnect/logout` pour la majorité des cas :

```ruby
redirect_to "/auth/proconnect/logout"
```

## Contribution

La stratégie est loin d'être complète ; n'hésitez pas à contribuer des
issues ou des changements.
