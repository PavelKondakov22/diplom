# -----Snapshot -----
resource "yandex_compute_snapshot_schedule" "mysnapshot" {
  name = "snapshot"

  schedule_policy {
    expression = "0 1 * * *"
  }

  snapshot_count = 7

  snapshot_spec {
      description = "Daily snapshot"
 }

  retention_period = "168h"

  labels = {
    my-label = "my-label-value"
  }

  disk_ids = [ yandex_compute_instance.nginx-1.boot_disk.0.disk_id, yandex_compute_instance.nginx-2.boot_disk.0.disk_id, yandex_compute_instance.bastion.boot_disk.0.disk_id, yandex_compute_instance.elastic.boot_disk.0.disk_id, yandex_compute_instance.kibana.boot_disk.0.disk_id, yandex_compute_instance.zabbix.boot_disk.0.disk_id]
           
}
