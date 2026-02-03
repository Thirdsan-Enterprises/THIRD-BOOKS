<?php
/**
 * Admin Panel Footer Layout
 */
if (!defined('ADMIN_PANEL')) {
    die('Direct access not permitted');
}
?>
            </div><!-- /.content -->
        </main><!-- /.main-content -->
    </div><!-- /.admin-layout -->

    <script>
        // Simple JavaScript for admin panel
        document.addEventListener('DOMContentLoaded', function() {
            // Auto-hide alerts after 5 seconds
            const alerts = document.querySelectorAll('.alert');
            alerts.forEach(function(alert) {
                setTimeout(function() {
                    alert.style.opacity = '0';
                    setTimeout(function() {
                        alert.remove();
                    }, 300);
                }, 5000);
            });

            // Confirm delete actions
            const deleteButtons = document.querySelectorAll('[data-confirm]');
            deleteButtons.forEach(function(button) {
                button.addEventListener('click', function(e) {
                    if (!confirm(this.dataset.confirm)) {
                        e.preventDefault();
                    }
                });
            });
        });
    </script>
</body>
</html>
