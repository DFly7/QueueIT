#
//  ci_post_clone.sh
//  QueueIT
//
//  Created by Darragh Flynn on 18/03/2026.
//

#!/bin/sh

# 1. Navigate to where the build expects the config file
# Adjust "QueueIT" if your folder structure is different
cd $CI_PRIMARY_REPOSITORY_PATH/QueueIT

# 2. Re-create the xcconfig file using the Environment Variables
# Replace KEY_NAME with whatever your actual keys are in the portal
echo "BACKEND_URL = $BACKEND_URL" >> Config-Release.xcconfig
echo "SUPABASE_URL = $SUPABASE_URL" >> Config-Release.xcconfig
echo "SUPABASE_ANON_KEY = $SUPABASE_ANON_KEY" >> Config-Release.xcconfig

echo "✅ Created Config-Release.xcconfig from Environment Variables"
