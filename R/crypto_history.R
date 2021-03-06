#' Get historic crypto currency market data
#'
#' Scrape the crypto currency historic market tables from
#' CoinMarketCap <https://coinmarketcap.com> and display
#' the results in a date frame. This can be used to conduct
#' analysis on the crypto financial markets or to attempt
#' to predict future market movements or trends.
#'
#' @param coin string Name, symbol or slug of crypto currency, default is all tokens
#' @param limit integer Return the top n records, default is all tokens
#' @param start_date string Start date to retrieve data from, format 'yyyymmdd'
#' @param end_date string End date to retrieve data from, format 'yyyymmdd'
#' @param coin_list string Valid values are 'api', 'static' or NULL
#' @param sleep integer Seconds to sleep for between API requests
#
#' @return Crypto currency historic OHLC market data in a dataframe:
#'   \item{slug}{Coin url slug}
#'   \item{symbol}{Coin symbol}
#'   \item{name}{Coin name}
#'   \item{date}{Market date}
#'   \item{ranknow}{Current Rank}
#'   \item{open}{Market open}
#'   \item{high}{Market high}
#'   \item{low}{Market low}
#'   \item{close}{Market close}
#'   \item{volume}{Volume 24 hours}
#'   \item{market}{USD Market cap}
#'   \item{close_ratio}{Close rate, min-maxed with the high and low values that day}
#'   \item{spread}{Volatility premium, high minus low for that day}
#'
#' This is the main function of the crypto package. If you want to retrieve
#' ALL coins then do not pass a argument to crypto_history(), or pass the coin name.
#'
#' @importFrom dplyr '%>%' 'mutate' 'arrange'
#' @importFrom tidyr 'replace_na'
#' @importFrom crayon 'make_style'
#' @importFrom grDevices 'rgb'
#' @importFrom tibble 'tibble' 'as_tibble'
#' @importFrom cli 'cat_bullet'
#' @importFrom lubridate 'mdy'
#'
#' @import progress
#' @import stats
#'
#' @examples
#' \dontrun{
#'
#' # Retrieving market history for ALL crypto currencies
#' all_coins <- crypto_history(limit = 1)
#'
#' # Retrieving this years market history for ALL crypto currencies
#' all_coins <- crypto_history(start_date = '20180101')
#' }
#' @name crypto_history
#'
#' @export
#'
crypto_history <- function(coin       = NULL,
                           limit      = NULL,
                           start_date = NULL,
                           end_date   = NULL,
                           coin_list  = NULL,
                           sleep      = NULL
) {
  pink <- crayon::make_style(grDevices::rgb(0.93, 0.19, 0.65))
  options(scipen = 999)
  i       <- "i"
  timestamp <- NULL
  low     <- NULL
  high    <- NULL
  close   <- NULL
  ranknow <- NULL

  message(cli::cat_bullet("If this helps you become rich please consider donating", bullet = "heart", bullet_col = pink))
  message("ERC-20: 0x375923Bf82F0b728d23A5704261a6e16341fd860", appendLF = TRUE)
  message("XRP: rK59semLsuJZEWftxBFhWuNE6uhznjz2bK", appendLF = TRUE)
  message("\n")

  coins <- crypto_list(coin, start_date, end_date, coin_list)

  if (!is.null(limit)) {coins <- coins[1:limit, ]}

  coin_names <- tibble::tibble(
      symbol = coins$symbol,
      name   = coins$name,
      rank   = coins$rank,
      slug   = coins$slug
  )

  to_scrape <- tibble::tibble(attributes = coins$history_url, slug = coins$slug)
  loop_data <- vector("list", nrow(to_scrape))

  message(cli::cat_bullet("Scraping historical crypto data", bullet = "pointer", bullet_col = "green"))
  pb <- progress_bar$new(format = ":spin [:current / :total] [:bar] :percent in :elapsedfull ETA: :eta", total = nrow(to_scrape), clear = FALSE)

  for (i in seq_len(nrow(to_scrape))) {
    pb$tick()
    loop_data[[i]] <- scraper(to_scrape$attributes[i], to_scrape$slug[i], sleep)
  }

  results <- do.call(rbind, loop_data) %>% tibble::as_tibble()

  if (nrow(results) == 0L) {
    stop("No data currently exists for this crypto currency.", call. = FALSE)
  }

    market_data <- merge(results, coin_names, by = "slug")

    market_data <- market_data %>% dplyr::mutate(
      date        = as.Date(substr(timestamp, 1, 10)),
      close_ratio = (close - low) / (high -  low) %>% round(4),
      spread      = (high - low) %>% round(2)
    ) %>% select("slug", "symbol", "name", "date", "ranknow" = "rank", "open", "high", "low", "close", "volume", "market" = "market_cap", "close_ratio", "spread") %>%
      dplyr::arrange(ranknow, date)

   market_data$close_ratio <- market_data$close_ratio %>% tidyr::replace_na(0)

   return(market_data)
}
