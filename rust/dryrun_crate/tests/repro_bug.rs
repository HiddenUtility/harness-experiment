use dryrun_crate::calculate_sum;

#[test]
fn test_calculate_sum_adds_correctly() {
    let result = calculate_sum(2, 3);
    assert_eq!(result, 5, "2 + 3 should be 5");
}
