import 'product.dart';

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.notes,
  });

  final Product product;
  final int quantity;
  final String? notes;

  CartItem copyWith({int? quantity, String? notes}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }
}
