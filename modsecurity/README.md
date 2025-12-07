# ModSecurity Configuration

Este directorio contiene la configuración y reglas de ModSecurity para el firewall de aplicaciones web (WAF).

## 📁 Estructura

```
modsecurity/
├── README.md              # Este archivo
├── modsecurity.conf       # Configuración principal de ModSecurity
└── rules/                 # Reglas de seguridad OWASP
    ├── REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example
    ├── REQUEST-901-INITIALIZATION.conf
    └── RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example
```

## 🔧 Configuración

ModSecurity está configurado en `docker-compose.yml` con el perfil `security`:

```bash
docker compose --profile security up -d
```

## 📝 Reglas OWASP

Las reglas están basadas en OWASP ModSecurity Core Rule Set (CRS) y proporcionan protección contra:

- Inyección SQL (SQL Injection)
- Cross-Site Scripting (XSS)
- Cross-Site Request Forgery (CSRF)
- Path Traversal
- Remote File Inclusion (RFI)
- Y otros ataques comunes

## ⚙️ Personalización

Para personalizar las reglas:

1. Edita los archivos en `rules/`
2. Reinicia el contenedor: `docker compose restart modsecurity`
3. Verifica los logs: `docker compose logs modsecurity`

## 📊 Logs

Los logs de ModSecurity se almacenan en el volumen `modsecurity_data` y pueden ser consultados con:

```bash
docker compose logs modsecurity
```

## 🔒 Notas de Seguridad

- Las reglas están configuradas en modo **Detección** por defecto
- Para producción, considera cambiar a modo **Bloqueo** después de probar
- Revisa los logs regularmente para ajustar falsos positivos

