import secrets
from authentik.core.models import User, Group, Application, Token
from authentik.providers.oauth2.models import OAuth2Provider, RedirectURI, RedirectURIMatchingMode
from authentik.flows.models import Flow, FlowStageBinding
from authentik.stages.authenticator_validate.models import AuthenticatorValidateStage
from authentik.policies.expression.models import ExpressionPolicy
from authentik.policies.models import PolicyBinding
from authentik.crypto.models import CertificateKeyPair

GROUPS = ["REDI Administrators", "REDI Developers", "REDI Operators"]
for name in GROUPS:
    Group.objects.get_or_create(name=name)
    print(f"group_ok:{name}")

admin = User.objects.get(username="akadmin")
for gname in ["REDI Administrators", "authentik Admins"]:
    g = Group.objects.filter(name=gname).first()
    if g and not admin.ak_groups.filter(pk=g.pk).exists():
        admin.ak_groups.add(g)
        print(f"admin_member:{gname}")

# API token for admin validation (rotate identifier if exists)
Token.objects.filter(identifier="redi-phase5-admin").delete()
token = Token.objects.create(
    user=admin,
    identifier="redi-phase5-admin",
    intent="api",
    description="REDI Phase 5 validation",
)
print(f"admin_token:{token.key}")

# MFA policy on default validation stage (already in default authentication flow)
mfa_validate = AuthenticatorValidateStage.objects.get(name="default-authentication-mfa-validation")
auth_flow_obj = Flow.objects.get(slug="default-authentication-flow")
mfa_binding = FlowStageBinding.objects.get(target=auth_flow_obj, order=30)
policy, _ = ExpressionPolicy.objects.get_or_create(
    name="REDI Administrators require MFA",
    defaults={
        "expression": 'return request.user.ak_groups.filter(name="REDI Administrators").exists()',
    },
)
PolicyBinding.objects.update_or_create(
    target=mfa_binding,
    policy=policy,
    defaults={"order": 0, "enabled": True},
)
print("policy_ok:redi-admin-mfa")

auth_flow = Flow.objects.get(slug="default-provider-authorization-implicit-consent")
invalid_flow = Flow.objects.get(slug="default-provider-invalidation-flow")
signing_key = CertificateKeyPair.objects.filter(name__icontains="authentik").first() or CertificateKeyPair.objects.first()

client_id = "redi-gitlab"
client_secret = secrets.token_urlsafe(32)
redirect_uris = [
    RedirectURI(
        matching_mode=RedirectURIMatchingMode.STRICT,
        url="https://git.letsredi.com/users/auth/openid_connect/callback",
    )
]

provider, created = OAuth2Provider.objects.update_or_create(
    name="REDI GitLab",
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
    slug="gitlab",
    defaults={
        "name": "REDI GitLab",
        "provider": provider,
        "meta_launch_url": "https://git.letsredi.com",
        "policy_engine_mode": "any",
    },
)
print(f"app_ok:{app.slug}")

svc, svc_created = User.objects.get_or_create(
    username="redi-developer",
    defaults={
        "name": "REDI Developer",
        "email": "developer@letsredi.com",
        "type": "internal",
        "is_active": True,
    },
)
if svc_created:
    svc.set_password(secrets.token_urlsafe(16))
    svc.save()
dev_group = Group.objects.get(name="REDI Developers")
if not svc.ak_groups.filter(pk=dev_group.pk).exists():
    svc.ak_groups.add(dev_group)
print("user_ok:redi-developer")

print(f"OIDC_CLIENT_ID={provider.client_id}")
print(f"OIDC_CLIENT_SECRET={provider.client_secret}")
print(f"OIDC_ISSUER=https://auth.letsredi.com/application/o/{app.slug}/")
