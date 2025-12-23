//
//  BlockedUsersViewController.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 23.12.25.
//  Copyright © 2025 Nina Wiedemann. All rights reserved.
//


import UIKit

final class BlockedUsersViewController: UITableViewController {

    private let store = BlockedUsersStore()
    private var blocked: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Blocked Users"

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        // Optional: show "Edit" button (enables delete controls)
        navigationItem.rightBarButtonItem = editButtonItem

        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    private func reloadData() {
        blocked = store.blockedIdsSorted()
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        blocked.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        let userId = blocked[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = "Blocked poster"
        content.secondaryText = userId
        cell.contentConfiguration = content
        cell.selectionStyle = .none

        return cell
    }

    // Unblock via swipe

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {

        let userId = blocked[indexPath.row]

        let unblock = UIContextualAction(style: .destructive, title: "Unblock") { [weak self] _, _, completion in
            guard let self else { completion(false); return }

            self.store.unblock(userId)

            // Update local model + animate row removal
            self.blocked.remove(at: indexPath.row)
            FilterViewController.hasChanged = true // mark for pin reload
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completion(true)
        }

        let config = UISwipeActionsConfiguration(actions: [unblock])
        config.performsFirstActionWithFullSwipe = true
        return config
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let userId = blocked[indexPath.row]
        store.unblock(userId)
        FilterViewController.hasChanged = true // mark for pin reload
        blocked.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}
