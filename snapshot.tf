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

  disk_ids = ["epd44q24ljbf5dfk041k", 
             "fhmrr4eae60p44cl627s",
             "fhms77dba28ju6qq736h",
             "fhmsmg9n33euhskmacb0",
             "fhmtrm9hfs6a44755me6",
             "fhmujcl1sfirsb34qno0"]
}
