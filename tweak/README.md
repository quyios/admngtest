# XXTExplorer Auth Bypass

Dylib inject để bỏ qua **toàn bộ** cơ chế xác thực Havoc, chạy offline hoàn toàn.

## Cấu trúc

```
tweak/
  Tweak.x   ← Source code hook (Logos/ObjC)
  Makefile  ← Build config (Theos)
  control   ← Package metadata
.github/workflows/
  build_bypass.yml  ← CI: build dylib + inject IPA
```

## Classes được hook

| Class | Tác dụng |
|---|---|
| `HVCKeychainHelper` | Trả token/secret giả, `accountExists` = YES |
| `HVCHavocAccount` | `isValid`/`isAuthenticated` = YES, token/secret giả |
| `HVCHavocSecret` | `isValid`/`isVerified` = YES |
| `HVCHavocConfiguration` | `isValid` = YES |
| `XXTEMoreLicenseController` | Vô hiệu hoá `presentPurchaseAlert`, `redirectToPurchasePage` |
| `NSURLSession` | Block `drm.82flex.com` + `havoc.app`, trả 200 OK fake |
| `NSURLConnection` | Block giống NSURLSession (API cũ) |

## Build thủ công (cần macOS + Theos)

```bash
cd tweak
make -j$(nproc) THEOS=/path/to/theos
```

## Build tự động (GitHub Actions)

1. Push code lên GitHub → workflow tự build
2. Vào **Actions → Build Auth Bypass & Patch IPA**
3. Chạy **workflow_dispatch** với `ipa_url` nếu muốn tự inject vào IPA

## Inject vào IPA thủ công (Azule)

```bash
azule -i XXTExplorer.ipa -f XXTExplorerAuthBypass.dylib -o XXTExplorer_Patched.ipa -n
```

## Cài đặt

- **TrollStore**: Cài trực tiếp file `.ipa` đã patch
- **Sideloadly**: Advanced → Inject dylib → chọn `XXTExplorerAuthBypass.dylib`
