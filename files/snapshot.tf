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

  disk_ids = ["epdn184ojqms8sn8vep9", 
             "fhm7btgk8jmbu3oba52j",
             "fhmf76ejv0jjfp9b6tkc",
             "fhmll00s89h8rodhvgs5",
             "fhmt7ta5v8plisfa6v3d",
             "fhmu0i18cp8sqogkd6qg"]
}
