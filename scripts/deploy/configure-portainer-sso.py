import secrets
from authentik.core.models import Application
from authentik.providers.oauth2.models import OAuth2Provider, RedirectURI, RedirectURIMatchingMode
from authentik.flows.models import Flow
from authentik.crypto.models import CertificateKeyPair

auth_flow = Flow.objects.get(slug="default-provider-authorization-implicit-consent")
invalid_flow = Flow.objects.get(slug="default-provider-invalidation-flow")
signing_key = CertificateKeyPair.objects.filter(name__icontains="authentik").first() or CertificateKeyPair.objects.first()

client_id = "redi-portainer"
client_secret = secrets.token_urlsafe(32)
redirect_uris = [
    RedirectURI(
        matching_mode=RedirectURIMatchingMode.STRICT,
        url="https://portainer.letsredi.com/",
    )
]

provider, created = OAuth2Provider.objects.update_or_create(
    name="REDI Portainer",
    defaults={
        "authorization_flow": auth_flow,
        "invalidation_flow": invalid_flow,
        "client_type": "confidential",
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uris": redirect_uris,
        "signing_key": signing_key,
        "sub_mode": "user_username",
        "issuer_mode": "per_provider",
    },
)
if not created:
    provider.client_secret = client_secret
    provider.redirect_uris = redirect_uris
    provider.save()
print(f"provider_ok:{provider.client_id}")

app, _ = Application.objects.update_or_create(
    slug="portainer",
    defaults={
        "name": "REDI Portainer",
        "provider": provider,
        "meta_launch_url": "https://portainer.letsredi.com",
        "policy_engine_mode": "any",
    },
)
print(f"app_ok:{app.slug}")
print(f"OIDC_CLIENT_ID={provider.client_id}")
print(f"OIDC_CLIENT_SECRET={provider.client_secret}")
print(f"OIDC_AUTH_URL=https://auth.letsredi.com/application/o/authorize/")
print(f"OIDC_TOKEN_URL=https://auth.letsredi.com/application/o/token/")
print(f"OIDC_USERINFO_URL=https://auth.letsredi.com/application/o/userinfo/")
print(f"OIDC_LOGOUT_URL=https://auth.letsredi.com/application/o/{app.slug}/end-session/")
