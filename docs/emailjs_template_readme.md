# EmailJS Template untuk Owrite Feedback

Setup EmailJS untuk menerima feedback dari aplikasi Owrite.

## Setup Steps

1. **Daftar di [EmailJS](https://emailjs.com)**
2. **Buat Email Service** → Connect ke Gmail
3. **Buat Email Template** → Copy template HTML dibawah
4. **Update `feedback_service.dart`:**
   ```dart
   static const String _emailJsServiceId = 'YOUR_SERVICE_ID';
   static const String _emailJsTemplateId = 'YOUR_TEMPLATE_ID';
   static const String _emailJsPublicKey = 'YOUR_PUBLIC_KEY';
   ```

---

## Email Template HTML

Copy ke **EmailJS → Email Templates → Create New Template → Edit Content (HTML)**

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  </head>
  <body
    style="margin: 0; padding: 0; background-color: #0a0a0a; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;"
  >
    <table
      role="presentation"
      width="100%"
      cellspacing="0"
      cellpadding="0"
      style="background-color: #0a0a0a;"
    >
      <tr>
        <td align="center" style="padding: 40px 20px;">
          <!-- Main Container -->
          <table
            role="presentation"
            width="600"
            cellspacing="0"
            cellpadding="0"
            style="background-color: #1a1a1a; border-radius: 16px; overflow: hidden;"
          >
            <!-- Header -->
            <tr>
              <td
                style="background: linear-gradient(135deg, #CCFF00 0%, #a8d600 100%); padding: 24px 32px;"
              >
                <table
                  role="presentation"
                  width="100%"
                  cellspacing="0"
                  cellpadding="0"
                >
                  <tr>
                    <td>
                      <h1
                        style="margin: 0; color: #000000; font-size: 24px; font-weight: 700;"
                      >
                        📝 Feedback Baru
                      </h1>
                      <p
                        style="margin: 8px 0 0; color: #333333; font-size: 14px;"
                      >
                        Owrite News App
                      </p>
                    </td>
                    <td align="right" valign="middle">
                      <span
                        style="display: inline-block; background-color: #000000; color: #CCFF00; padding: 8px 16px; border-radius: 20px; font-size: 12px; font-weight: 600;"
                        >⭐ {{app_rating}}/5</span
                      >
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- User Info Section -->
            <tr>
              <td style="padding: 24px 32px; border-bottom: 1px solid #2a2a2a;">
                <table
                  role="presentation"
                  width="100%"
                  cellspacing="0"
                  cellpadding="0"
                >
                  <tr>
                    <td width="50%" style="padding-right: 12px;">
                      <p
                        style="margin: 0 0 4px; color: #666666; font-size: 11px; text-transform: uppercase; letter-spacing: 1px;"
                      >
                        Nama
                      </p>
                      <p
                        style="margin: 0; color: #ffffff; font-size: 16px; font-weight: 600;"
                      >
                        {{user_name}}
                      </p>
                    </td>
                    <td width="25%" style="padding: 0 12px;">
                      <p
                        style="margin: 0 0 4px; color: #666666; font-size: 11px; text-transform: uppercase; letter-spacing: 1px;"
                      >
                        Umur
                      </p>
                      <p
                        style="margin: 0; color: #ffffff; font-size: 16px; font-weight: 600;"
                      >
                        {{user_age}} tahun
                      </p>
                    </td>
                    <td width="25%" style="padding-left: 12px;">
                      <p
                        style="margin: 0 0 4px; color: #666666; font-size: 11px; text-transform: uppercase; letter-spacing: 1px;"
                      >
                        Profesi
                      </p>
                      <p
                        style="margin: 0; color: #CCFF00; font-size: 16px; font-weight: 600;"
                      >
                        {{user_profession}}
                      </p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Improvements Section -->
            <tr>
              <td style="padding: 24px 32px; border-bottom: 1px solid #2a2a2a;">
                <table
                  role="presentation"
                  width="100%"
                  cellspacing="0"
                  cellpadding="0"
                >
                  <tr>
                    <td>
                      <p
                        style="margin: 0 0 8px; color: #CCFF00; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;"
                      >
                        🔧 Yang Perlu Ditingkatkan
                      </p>
                      <p
                        style="margin: 0; color: #cccccc; font-size: 15px; line-height: 1.6; background-color: #2a2a2a; padding: 16px; border-radius: 8px; border-left: 3px solid #CCFF00;"
                      >
                        {{improvements}}
                      </p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Desired Features Section -->
            <tr>
              <td style="padding: 24px 32px; border-bottom: 1px solid #2a2a2a;">
                <table
                  role="presentation"
                  width="100%"
                  cellspacing="0"
                  cellpadding="0"
                >
                  <tr>
                    <td>
                      <p
                        style="margin: 0 0 8px; color: #CCFF00; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;"
                      >
                        ✨ Fitur yang Diinginkan
                      </p>
                      <p
                        style="margin: 0; color: #cccccc; font-size: 15px; line-height: 1.6; background-color: #2a2a2a; padding: 16px; border-radius: 8px; border-left: 3px solid #CCFF00;"
                      >
                        {{desired_features}}
                      </p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Ideal Description Section -->
            <tr>
              <td style="padding: 24px 32px; border-bottom: 1px solid #2a2a2a;">
                <table
                  role="presentation"
                  width="100%"
                  cellspacing="0"
                  cellpadding="0"
                >
                  <tr>
                    <td>
                      <p
                        style="margin: 0 0 8px; color: #CCFF00; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;"
                      >
                        💡 Aplikasi Berita Ideal
                      </p>
                      <p
                        style="margin: 0; color: #cccccc; font-size: 15px; line-height: 1.6; background-color: #2a2a2a; padding: 16px; border-radius: 8px; border-left: 3px solid #CCFF00;"
                      >
                        {{ideal_description}}
                      </p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Footer -->
            <tr>
              <td style="padding: 20px 32px; background-color: #0f0f0f;">
                <table
                  role="presentation"
                  width="100%"
                  cellspacing="0"
                  cellpadding="0"
                >
                  <tr>
                    <td>
                      <p style="margin: 0; color: #666666; font-size: 12px;">
                        Dikirim pada: {{submitted_at}}
                      </p>
                    </td>
                    <td align="right">
                      <p style="margin: 0; color: #666666; font-size: 12px;">
                        Owrite v1.0.3
                      </p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
```

---

## Template Variables

| Variable                | Deskripsi                 |
| ----------------------- | ------------------------- |
| `{{user_name}}`         | Nama pengguna             |
| `{{user_age}}`          | Umur pengguna             |
| `{{user_profession}}`   | Profesi dari dropdown     |
| `{{app_rating}}`        | Rating 1-5                |
| `{{improvements}}`      | Saran peningkatan         |
| `{{desired_features}}`  | Fitur yang diinginkan     |
| `{{ideal_description}}` | Deskripsi aplikasi ideal  |
| `{{submitted_at}}`      | Waktu submit (ISO format) |

---

## Subject Line Template

```
[Owrite Feedback] ⭐ {{app_rating}}/5 dari {{user_name}}
```
