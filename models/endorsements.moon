
db = require "lapis.db"
import Model from require "lapis.db.model"

import increment_counter from require "helpers.models"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE endorsements (
--   user_id integer NOT NULL,
--   module_id integer NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY endorsements
--   ADD CONSTRAINT endorsements_pkey PRIMARY KEY (user_id, module_id);
--
class Endorsements extends Model
  @primary_key: {"user_id", "module_id"}
  @timestamp: true

  @relations: {
    {"module", belongs_to: "Modules"}
    {"user", belongs_to: "Users"}
  }

  @endorse: (user, mod) =>
    tbl_name = db.escape_identifier @table_name!
    now = db.format_date!
    res = db.query "
      insert into #{tbl_name} (user_id, module_id, created_at, updated_at)
      select ?, ?, ?, ? where not exists(
        select 1 from #{tbl_name} where user_id = ? and module_id = ?
      ) returning user_id, module_id, created_at, updated_at
    ", user.id, mod.id, now, now, user.id, mod.id

    created = res.affected_rows
    return nil, "already endorsed" unless created and created > 0

    increment_counter mod, "endorsements_count"
    Endorsements\load unpack res

  delete: =>
    if super!
      increment_counter @get_module!, "endorsements_count", -1

