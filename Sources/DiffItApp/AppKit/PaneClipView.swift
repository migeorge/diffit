import AppKit

/// Clip view whose content insets stay zero.
///
/// Whenever a pane's document is wider than the pane, `NSScrollView.tile()` gives its clip view a
/// bottom inset the thickness of the overlay horizontal scroller, so the last row can be scrolled
/// out from under the scroller. That lengthens the pane's scroll range by the inset, and the inset
/// is not withdrawn when the document shrinks to fit again. A pane scrolled (or rubber-banded) to
/// the end then rests where its partner cannot follow, and the rows stay misaligned until the user
/// scrolls back up. Both panes must share one scroll range, so the inset is refused: the overlay
/// scroller covers the last row only while it is shown. See DECISIONS.md.
final class PaneClipView: NSClipView {
    override var contentInsets: NSEdgeInsets {
        get { super.contentInsets }
        set { super.contentInsets = NSEdgeInsetsZero }
    }
}
