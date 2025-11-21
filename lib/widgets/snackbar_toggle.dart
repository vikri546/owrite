import 'package:flutter/material.dart';

void showBookmarkSnackbar(BuildContext context, bool isBookmarked) {
  if (context.mounted == false) return;
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isBookmarked
                ? Icons.bookmark_add_rounded
                : Icons.bookmark_remove_rounded,
            color: isBookmarked
                ? const Color(0xFFE5FF10)
                : Colors.red[300],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isBookmarked
                  ? "Artikel disimpan ke bookmark"
                  : "Artikel dihapus dari bookmark",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF333333),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

/// Show a snackbar for Sort & Filter action, matching the bookmark snackbar UI.
/// [sortLabel] should be a string like "Terbaru" or "Terlama".
/// [categoryCount] is the number of categories applied.
void showSortFilterSnackbar(
  BuildContext context, {
  required String sortLabel,
  required int categoryCount,
}) {
  if (context.mounted == false) return;
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: Color(0xFFE5FF10)),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                children: [
                  const TextSpan(text: "Filter diterapkan"),
                  TextSpan(
                    text: " (Sort: ",
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  TextSpan(
                    text: sortLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5FF10),
                    ),
                  ),
                  TextSpan(
                    text: ", Kategori: ",
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  TextSpan(
                    text: "$categoryCount",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5FF10),
                    ),
                  ),
                  const TextSpan(
                    text: ")",
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF333333),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
