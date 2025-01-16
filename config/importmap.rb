# config/importmap.rb
pin "application"
pin "@hotwired/turbo-rails"
pin "@hotwired/stimulus"
pin "@hotwired/stimulus-loading"
# Chart.jsのCDNを追加
pin "chart.js/auto", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"
