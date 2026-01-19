# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Merchant.Repo.insert!(%Merchant.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Merchant.Repo
alias Merchant.Store.Product

products = [
  # Electronics
  %{
    sku: "LAPTOP-PRO",
    title: "ProBook Laptop 15\"",
    description:
      "Powerful laptop with 16GB RAM, 512GB SSD, and a stunning 15.6\" display. Perfect for professionals and creators.",
    price_cents: 129_999,
    image_url: "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400",
    stock: 25,
    category: "Electronics",
    active: true
  },
  %{
    sku: "PHONE-X1",
    title: "SmartPhone X1",
    description:
      "Latest smartphone with 6.5\" OLED display, 128GB storage, and advanced camera system.",
    price_cents: 79999,
    image_url: "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400",
    stock: 50,
    category: "Electronics",
    active: true
  },
  %{
    sku: "HEADPHONES-BT",
    title: "Wireless Noise-Canceling Headphones",
    description:
      "Premium wireless headphones with active noise cancellation and 30-hour battery life.",
    price_cents: 24999,
    image_url: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400",
    stock: 75,
    category: "Electronics",
    active: true
  },
  %{
    sku: "TABLET-AIR",
    title: "AirTab Pro 11\"",
    description:
      "Ultra-thin tablet with 11\" Retina display, perfect for work and entertainment.",
    price_cents: 59999,
    image_url: "https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=400",
    stock: 30,
    category: "Electronics",
    active: true
  },
  %{
    sku: "SMARTWATCH-S3",
    title: "FitWatch Series 3",
    description: "Advanced smartwatch with health monitoring, GPS, and 7-day battery life.",
    price_cents: 29999,
    image_url: "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400",
    stock: 60,
    category: "Electronics",
    active: true
  },

  # Home & Office
  %{
    sku: "DESK-STAND",
    title: "Ergonomic Standing Desk",
    description: "Height-adjustable standing desk with memory presets. 60\" x 30\" work surface.",
    price_cents: 49999,
    image_url: "https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd?w=400",
    stock: 15,
    category: "Home & Office",
    active: true
  },
  %{
    sku: "CHAIR-ERGO",
    title: "Executive Ergonomic Chair",
    description:
      "Premium office chair with lumbar support, adjustable armrests, and breathable mesh back.",
    price_cents: 39999,
    image_url: "https://images.unsplash.com/photo-1580480055273-228ff5388ef8?w=400",
    stock: 20,
    category: "Home & Office",
    active: true
  },
  %{
    sku: "MONITOR-4K",
    title: "UltraView 27\" 4K Monitor",
    description: "27-inch 4K IPS monitor with USB-C connectivity and built-in speakers.",
    price_cents: 44999,
    image_url: "https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=400",
    stock: 35,
    category: "Home & Office",
    active: true
  },
  %{
    sku: "LAMP-DESK",
    title: "LED Desk Lamp with Wireless Charger",
    description:
      "Modern desk lamp with adjustable brightness, color temperature, and built-in wireless charging.",
    price_cents: 5999,
    image_url: "https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=400",
    stock: 100,
    category: "Home & Office",
    active: true
  },

  # Accessories
  %{
    sku: "KEYBOARD-MECH",
    title: "Mechanical Gaming Keyboard",
    description: "RGB mechanical keyboard with Cherry MX switches and programmable macros.",
    price_cents: 14999,
    image_url: "https://images.unsplash.com/photo-1511467687858-23d96c32e4ae?w=400",
    stock: 45,
    category: "Accessories",
    active: true
  },
  %{
    sku: "MOUSE-WIRELESS",
    title: "Precision Wireless Mouse",
    description: "Ergonomic wireless mouse with 4000 DPI sensor and silent clicks.",
    price_cents: 4999,
    image_url: "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=400",
    stock: 80,
    category: "Accessories",
    active: true
  },
  %{
    sku: "WEBCAM-HD",
    title: "StreamPro 4K Webcam",
    description:
      "Professional 4K webcam with auto-focus, low-light correction, and built-in mic.",
    price_cents: 12999,
    image_url: "https://images.unsplash.com/photo-1587826080692-f439cd0b70da?w=400",
    stock: 40,
    category: "Accessories",
    active: true
  },
  %{
    sku: "USB-HUB",
    title: "USB-C Hub 7-in-1",
    description: "Compact USB-C hub with HDMI, USB-A ports, SD card reader, and power delivery.",
    price_cents: 4999,
    image_url: "https://images.unsplash.com/photo-1625723044792-44de16ccb4e9?w=400",
    stock: 120,
    category: "Accessories",
    active: true
  },
  %{
    sku: "CHARGER-MULTI",
    title: "100W GaN Multi-Port Charger",
    description:
      "Compact 100W charger with 3 USB-C ports and 1 USB-A port. Fast charging for all devices.",
    price_cents: 6999,
    image_url: "https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=400",
    stock: 90,
    category: "Accessories",
    active: true
  },

  # Lifestyle
  %{
    sku: "BACKPACK-TECH",
    title: "Tech Travel Backpack",
    description:
      "Water-resistant backpack with laptop compartment, USB charging port, and TSA-friendly design.",
    price_cents: 8999,
    image_url: "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400",
    stock: 55,
    category: "Lifestyle",
    active: true
  },
  %{
    sku: "BOTTLE-SMART",
    title: "Smart Water Bottle",
    description: "Insulated smart water bottle with temperature display and hydration reminders.",
    price_cents: 3499,
    image_url: "https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=400",
    stock: 70,
    category: "Lifestyle",
    active: true
  },
  %{
    sku: "SPEAKER-PORT",
    title: "Portable Bluetooth Speaker",
    description: "Waterproof portable speaker with 360° sound and 20-hour battery life.",
    price_cents: 7999,
    image_url: "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=400",
    stock: 65,
    category: "Lifestyle",
    active: true
  },
  %{
    sku: "EARBUDS-PRO",
    title: "True Wireless Earbuds Pro",
    description: "Premium wireless earbuds with ANC, transparency mode, and 8-hour battery life.",
    price_cents: 17999,
    image_url: "https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=400",
    stock: 85,
    category: "Lifestyle",
    active: true
  },

  # Books (low-priced items)
  %{
    sku: "BOOK-ELIXIR",
    title: "Programming Elixir 1.18",
    description:
      "The definitive guide to Elixir programming. Learn functional programming and OTP.",
    price_cents: 4499,
    image_url: "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400",
    stock: 200,
    category: "Books",
    active: true
  },
  %{
    sku: "BOOK-PHOENIX",
    title: "Phoenix LiveView Handbook",
    description:
      "Master real-time web applications with Phoenix LiveView. Includes practical examples.",
    price_cents: 3999,
    image_url: "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400",
    stock: 150,
    category: "Books",
    active: true
  }
]

IO.puts("Seeding #{length(products)} products...")

Enum.each(products, fn product_attrs ->
  %Product{}
  |> Product.changeset(product_attrs)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :sku)
end)

IO.puts("Done! Products seeded successfully.")
