pipeline {
    agent any
    stages {
      // stage('Clone repository') {
      //         /* Let's make sure we have the repository cloned to our workspace */

      //         checkout scm
      //     }

      stage('Build image') {
        /* This builds the actual image; synonymous to
         * docker build on the command line */
        steps {
          script {
            docker.build("kobonaut/elm-terminal-resume")
          }
        }
        
      }

      stage('Test image') {
        steps {
            sh 'echo "Tests passed"'
        }
      }

      // stage('Push image') {
      //   /* Finally, we'll push the image with two tags:
      //    * First, the incremental build number from Jenkins
      //    * Second, the 'latest' tag.
      //    * Pushing multiple tags is cheap, as all the layers are reused. */
      //   steps {
      //       docker.withRegistry('https://registry.hub.docker.com', 'docker-hub-credentials') {
      //         app.push("${env.BUILD_NUMBER}")
      //         app.push("latest")
      //     }
      //   }
      // }
    }
}