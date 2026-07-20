import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/gitlab_pagination_utils.dart';

void main() {
  test('parseGitLabPagination uses x-total-pages headers', () {
    final info = parseGitLabPagination(
      headers: const {
        'x-page': '2',
        'x-total-pages': '5',
        'x-total': '100',
        'x-per-page': '20',
      },
      requestedPage: 2,
      requestedPerPage: 20,
      rawItemCount: 20,
    );

    expect(info.currentPage, 2);
    expect(info.totalPages, 5);
    expect(info.hasNextPage, isTrue);
  });

  test('parseGitLabPagination computes pages from x-total when needed', () {
    final info = parseGitLabPagination(
      headers: const {
        'x-page': '1',
        'x-total': '45',
        'x-per-page': '20',
      },
      requestedPage: 1,
      requestedPerPage: 20,
      rawItemCount: 20,
    );

    expect(info.totalPages, 3);
    expect(info.hasNextPage, isTrue);
  });

  test('parseGitLabPagination parses Link header', () {
    final info = parseGitLabPagination(
      headers: const {
        'link':
            '<https://gitlab.example.com/api/v4/projects/1/jobs?page=2&per_page=20>; rel="next", '
            '<https://gitlab.example.com/api/v4/projects/1/jobs?page=4&per_page=20>; rel="last"',
      },
      requestedPage: 1,
      requestedPerPage: 20,
      rawItemCount: 20,
    );

    expect(info.totalPages, 4);
    expect(info.hasNextPage, isTrue);
  });

  test('parseGitLabPagination assumes more pages on full raw page', () {
    final info = parseGitLabPagination(
      headers: const {},
      requestedPage: 1,
      requestedPerPage: 20,
      rawItemCount: 20,
    );

    expect(info.totalPages, 1);
    expect(info.hasNextPage, isTrue);
  });
}
