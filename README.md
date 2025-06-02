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

La suite du README décrit brièvement la configuration de la librairie. Si vous
n'êtes pas encore familier avec OIDC et OmniAuth, un [guide complet de
configuration d'omniauth-proconnect est aussi disponible sur le
wiki](https://github.com/betagouv/omniauth-proconnect/wiki/Guide-de-connexion).

## Utilisation

Une fois que vous avez créé votre application sur [l'espace
partenaires de
ProConnect](https://partenaires.proconnect.gouv.fr/apps) et identifié
vos endpoints grâce à leur [documentation
technique](https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique)
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

**⚠️ NOTE :** [La valeur de `PROCONNECT_DOMAIN` doit finir par
`/api/v2`](https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique#12-valeur-de-proconnect_domain),
ce n'est pas seulement l'hôte. C.f https://github.com/betagouv/omniauth-proconnect/issues/5

3.  envoyez votre utilisateur sur la stratégie :

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

## Informations retournées

Les [informations retournées par
ProConnect](https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/scope-claims)
sont mises à diposition dans le hash OmniAuth
(`request.env["omniauth.auth"]`) :

- la partie `info` contient tout ce qui peut être standardisé [selon
  le Auth Hash Schema d'Omniauth](https://github.com/omniauth/omniauth/wiki/Auth-Hash-Schema)
- le reste/l'intégralité est disponible dans `extra`.

Exemple :

```json
{
  "provider": "proconnect",
  "uid": "e7a41249-123d-46b7-b362-5f00d3166ea1",
  "info": {
    "email": "test@gouv.fr",
    "first_name": null,
    "last_name": null,
    "name": "",
    "phone": null,
    "provider": "proconnect",
    "uid": "e7a41249-123d-46b7-b362-5f00d3166ea1"
  },
  "credentials": {},
  "extra": {
    "raw_info": {
      "sub": "e7a41249-123d-46b7-b362-5f00d3166ea1",
      "email": "test@gouv.fr",
      "siret": "13002526500013",
      "aud": "f90c1231117ec6f731af9f93a07c54ff372130c17a3bbad43488699865d85c64",
      "exp": 1748010049,
      "iat": 1748009989,
      "iss": "https://issuer-oidc.gouv.fr/api/v42"
    }
  }
}
```

```ruby
class SessionsController < ApplicationController
  def create
    data = request.env["omniauth.auth"]

    email = data.info.email
    siret = data.extra.raw_info.siret

    # or, if you're feeling fancy
    data => { info: { email: }, extra: { raw_info: { siret: } } }

    # [...]
  end
end
```

## Contribution

La stratégie est loin d'être complète ; n'hésitez pas à contribuer des
issues ou des changements.
