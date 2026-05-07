# Ro Token Sistemi

Bu klasör Ro Desktop tasarım sisteminin ana kaynağıdır.

## Dosyalar

- `colors.light.json`: Aydınlık tema renkleri
- `colors.dark.json`: Karanlık tema renkleri
- `spacing.json`: Boşluk değerleri
- `radius.json`: Köşe yuvarlaklığı değerleri
- `opacity.json`: Glassmorphism ve yüzey opaklıkları
- `motion.json`: Animasyon süreleri ve hareket değerleri

## Kural

Tema veya uygulama geliştirirken rastgele hex renk yazma. Önce buradaki token dosyalarını kullan.

Yanlış:

```css
background: #123456;
```

Doğru:

```css
background: var(--ro-accent);
```
