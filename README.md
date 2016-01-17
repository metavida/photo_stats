# First Years Photo Stats

Doing some light-weight analysis of the photos I've taken over first years of our boys' lives.

## Usage

Basic usage for the first year of life/photos

````bash
$ bundle install
$ bundle exec ./photo_stats.rb --birthday='YYYY-MM-DD' ~/Dropbox/Photos/Family\ Photos/
$ bundle exec jekyll server --watch
````

### Advanced Usage

By default the "top_10.csv" file is never overwritten, because it has columns for human-entered info, like a photo to use & a description of the event. To regenerate this file, use the `--top10` option.

````bash
$ bundle exec ./photo_stats.rb --birthday='YYYY-MM-DD' --top10 ~/Dropbox/Photos/Family\ Photos/
````

To get stats for the 2nd year of life (days 366-730) use the `--year=` option.

````bash
$ bundle exec ./photo_stats.rb --birthday='YYYY-MM-DD' --year=2 ~/Dropbox/Photos/Family\ Photos/
````

## Licenses

Files in the project use several licenses. See [LICENSE.txt] for details.