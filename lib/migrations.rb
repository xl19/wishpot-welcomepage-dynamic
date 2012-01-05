require 'dm-migrations/migration_runner'

DataMapper::Logger.new(STDOUT, :debug)
DataMapper.logger.debug( "Starting Migration" )

migration 1, :allow_multiple_tabs do
  up do
    DataMapper.logger.debug( "Migration 1 UP" )
    
    #This part is irreversible.  It sets the welcome page to our default app id.  This should be safe because we didn't create multiple
    #apps until after we added the code that inserts the app_id when a new page is created
    execute "UPDATE welcome_pages SET app_id='210073625689149' WHERE app_id IS NULL;"
    
    #At first, the new column allows nulls, then we fill it
    execute "ALTER TABLE collected_emails ADD COLUMN welcome_page_app_id VARCHAR(50) NULL"
    
    #This update relies on the fact that page_id used to be the primary key, therefore there is only one result returned in the subquery
    execute "UPDATE collected_emails SET welcome_page_app_id=(SELECT app_id from welcome_pages WHERE welcome_pages.page_id=collected_emails.welcome_page_page_id)"
    
    execute "ALTER TABLE welcome_pages DROP CONSTRAINT welcome_pages_pkey; ALTER TABLE welcome_pages ADD PRIMARY KEY (page_id, app_id);"
    
    #now, we can safely define the table as non-nullable
    execute "ALTER TABLE collected_emails ALTER COLUMN welcome_page_app_id SET NOT NULL"
  end

  down do
    DataMapper.logger.debug( "Migration 1 DOWN" )
    execute 'ALTER TABLE welcome_pages DROP CONSTRAINT welcome_pages_pkey; ALTER TABLE welcome_pages ADD PRIMARY KEY (page_id);'
    execute 'ALTER TABLE collected_emails DROP COLUMN welcome_page_app_id;'
  end
end

migrate_up!
DataMapper.logger.debug( "Finished Migration" )

#migrate_down!