# Ro Tema Token Kullanım Rehberi

Bu dosya, Ro Desktop üzerinde uygulama veya arayüz geliştirecek kişiler için hazırlanmıştır. Amaç, sistemin tamamında aynı renk, boşluk, radius, opacity ve animasyon dilini korumaktır.

---

## Ana kural

Uygulama geliştirirken doğrudan renk yazma:

```css
/* Kötü */
background: #123456;
```

Bunun yerine token kullan:

```css
/* İyi */
background: var(--ro-accent);
```

---

## Kullanılacak dosyalar

Kaynak dosyalar:

```text
core/tokens/colors.light.json
core/tokens/colors.dark.json
core/tokens/spacing.json
core/tokens/radius.json
core/tokens/opacity.json
core/tokens/motion.json
```

Uygulamacılar için üretilmiş dosyalar:

```text
dist/tokens/ro-colors.css
dist/tokens/ro-colors.json
dist/tokens/ro-tailwind.js
```

---

## CSS değişkenleri

`dist/tokens/ro-colors.css` dosyası şu değişkenleri sağlar:

```css
--ro-bg
--ro-bg-alt
--ro-surface
--ro-surface-alt
--ro-glass
--ro-text
--ro-text-secondary
--ro-accent
--ro-border
--ro-radius-lg
--ro-radius-panel
--ro-motion-window-open
```

Örnek:

```css
.card {
  background: var(--ro-glass);
  color: var(--ro-text);
  border: 1px solid var(--ro-border);
  border-radius: var(--ro-radius-lg);
}
```

---

## Light/Dark desteği

Aydınlık tema varsayılandır. Karanlık tema için `data-ro-theme="dark"` kullanılabilir:

```html
<body data-ro-theme="dark">
```

CSS tarafında dark değerleri otomatik değişir:

```css
[data-ro-theme="dark"] {
  --ro-bg: #352F44;
  --ro-surface: #5C5470;
  --ro-accent: #B9B4C7;
  --ro-text: #FAF0E6;
}
```

---

## Glassmorphism kullanımı

Ro tasarımında cam hissi kullanılır ama abartılmaz. Çok bulanık ve sütlü cam görünümü amatör durur.

Önerilen kullanım:

```css
.panel {
  background: var(--ro-glass);
  border: 1px solid var(--ro-border);
  border-radius: var(--ro-radius-panel);
  backdrop-filter: blur(18px);
}
```

---

## Animasyon prensibi

Ro animasyon dili:

- hızlı
- sakin
- zıplamasız
- dikkat dağıtmayan
- uzun kullanımda yormayan

Önerilen süreler:

```text
küçük geçişler: 120ms - 160ms
pencere hissi: 140ms - 180ms
büyük ekran geçişleri: 200ms - 260ms
```

---

## Son söz

Ro uygulaması yazan herkes aynı token sistemini kullanırsa sistem tek parça görünür. Herkes kendi rengine kaçarsa proje parçalı ve amatör görünür.
