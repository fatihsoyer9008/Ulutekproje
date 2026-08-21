import html
from urllib.parse import urlencode

from fastapi.responses import HTMLResponse

from app.core.config import settings


def deep_link_landing_page(
    *,
    token: str,
    deep_link_path: str,
    title: str,
    description: str,
    button_label: str,
) -> HTMLResponse:
    """Bir https davet linkine tıklandığında açılan ara sayfa.

    E-posta istemcileri (Gmail dahil) özel URL şemalarını (fiskon://) e-posta
    gövdesinde tıklanabilir bağlantı olarak göstermiyor, bu yüzden davet
    e-postaları buraya (https) yönlendiriyor; bu sayfa da tıklandığında
    uygulamayı özel şema ile açıyor.
    """
    deep_link_base = settings.app_deep_link_base_url.rstrip("/")
    raw_app_url = f"{deep_link_base}/{deep_link_path}?{urlencode({'token': token})}"
    app_url = html.escape(raw_app_url, quote=True)
    content = f"""<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title} | EconBuddy</title>
</head>
<body style="margin:0;background:#f3faf7;font-family:Arial,sans-serif;color:#17312b">
  <main style="max-width:560px;margin:64px auto;padding:24px">
    <section style="background:white;border-radius:24px;padding:40px;
      box-shadow:0 12px 40px rgba(22,133,107,.12);text-align:center">
      <h1 style="margin:0 0 16px;color:#16856b">{title}</h1>
      <p style="font-size:17px;line-height:1.6;margin:0 0 24px">{description}</p>
      <a href="{app_url}" style="display:inline-block;border:0;border-radius:14px;
        padding:14px 24px;background:#16856b;color:white;font-size:16px;
        font-weight:bold;text-decoration:none">
        {button_label}
      </a>
      <p style="font-size:13px;color:#5b7b73;margin:24px 0 0">
        EconBuddy uygulaması açılmazsa, yüklü olduğundan emin olup tekrar dene.
      </p>
    </section>
  </main>
</body>
</html>"""
    return HTMLResponse(
        content=content,
        headers={
            "Cache-Control": "no-store",
            "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'",
            "Referrer-Policy": "no-referrer",
        },
    )
