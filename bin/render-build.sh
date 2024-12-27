set -o errexit

bundle install
yarn install
RAILS_ENV=production bundle exec rake assets:precompile
yarn run tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify
RAILS_ENV=production bundle exec rake db:migrate
