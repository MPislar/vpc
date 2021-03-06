#' Pipe/chain an object forward into a function call/expression.
#'
#' The \code{\%>\%} operator pipes the left-hand side into an expression on the
#' right-hand side. The expression can contain a \code{.} as placeholder to
#' indicate the position taken by the object in the pipeline. If not present,
#' it will be squeezed in as the first argument. If the right-hand side
#' expression is a function call that takes only one argument, one can omit
#' parentheses and the "\code{.}". Only the outmost call is matched against the
#' dot for the purpose of deciding the on placement of the left-hand side.
#' Using the "\code{.}" in nested calls/functions is also possible, but magrittr
#' will not try to book-keep the call in this case, which can be useful at
#' at times, see e.g. a plotting example below where labels change.
#'
#' @param lhs a value
#' @param rhs a function/call/expression. Enclose in parentheses to force
#' evaluation of rhs before piping is carried out, e.g. anonymous functions
#' or call-generating expressions.
#' @return The result of evaluting the right-hand side with the left-hand side
#' as the specified argument(s).
#' @rdname chain
#' @export
#' @examples
#' \dontrun{
#' library(dplyr)
#' library(Lahman)
#'
#' Batting %>%
#'   group_by(playerID) %>%
#'   summarise(total = sum(G)) %>%
#'   arrange(desc(total)) %>%
#'   head(5)
#'
#'
#' iris %>%
#'   filter(Petal.Length > 5) %>%
#'   select(-Species) %>%
#'   colMeans
#'
#' iris %>%
#'   aggregate(. ~ Species, ., mean)
#'
#' rnorm(1000) %>% abs %>% sum
#'
#' # Here, "." is used in a nested call to show how the call is not preserved
#' # in this case. It is visualized by noting the y-axis label.
#' 1:10 %>% plot(., col = .)      # not nested
#' 1:10 %>% plot(I(.), col = .)   # nested.
#'
#' # This examples shows how the placement of the lhs is independent of
#' # using . in a nested call:
#' 1:10 %>% rep(.)     # like rep(1:10)
#' 1:10 %>% rep(I(.))  # like 1:10 %>% rep(., .) and rep(1:10, 1:10)
#' }
`%>%` <- magrittr::`%>%`