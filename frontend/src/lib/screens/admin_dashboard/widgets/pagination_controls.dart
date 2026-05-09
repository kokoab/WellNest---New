part of 'package:my_app/screens/admin_dashboard.dart';

class _PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool loading;
  final ValueChanged<int> onPageChanged;

  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.loading,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First Page Button
              _PaginationButton(
                label: 'First',
                onPressed: currentPage > 1 && !loading
                    ? () => onPageChanged(1)
                    : null,
              ),
              const SizedBox(width: 4),
              // Previous Button
              _PaginationButton(
                label: 'Prev',
                onPressed: currentPage > 1 && !loading
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 8),
              // Page Numbers
              ..._buildPageNumbers(),
              const SizedBox(width: 8),
              // Next Button
              _PaginationButton(
                label: 'Next',
                onPressed: currentPage < totalPages && !loading
                    ? () => onPageChanged(currentPage + 1)
                    : null,
              ),
              const SizedBox(width: 4),
              // Last Page Button
              _PaginationButton(
                label: 'Last',
                onPressed: currentPage < totalPages && !loading
                    ? () => onPageChanged(totalPages)
                    : null,
              ),
              const SizedBox(width: 12),
              // Page Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kSurfaceWarmGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kPrimaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final List<Widget> buttons = [];
    final int startPage = (currentPage - 2).clamp(1, totalPages);
    final int endPage = (currentPage + 2).clamp(1, totalPages);

    // Add page numbers (show max 5 pages: [currentPage-2...currentPage+2])
    for (int i = startPage; i <= endPage; i++) {
      if (i > 1 && i < startPage) {
        buttons.add(const Text('...', style: TextStyle(fontSize: 12)));
        buttons.add(const SizedBox(width: 4));
      }

      buttons.add(
        _PaginationButton(
          label: '$i',
          isActive: i == currentPage,
          onPressed: i == currentPage || loading
              ? null
              : () => onPageChanged(i),
        ),
      );

      if (i < endPage) {
        buttons.add(const SizedBox(width: 4));
      }
    }

    return buttons;
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;

  const _PaginationButton({
    required this.label,
    this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      // Active page button
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        disabledForegroundColor: kCaptionGray.withOpacity(0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
